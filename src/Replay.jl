module Replay

using REPL

include("FakePTYs.jl")
using .FakePTYs: open_fake_pty

const CTRL_C = "\x03"
const TAB = "\t"
const UP_ARROW = "\e[A"
const DOWN_ARROW = "\e[B"
const RIGHT_ARROW = "\e[C"
const LEFT_ARROW = "\e[D"

export CTRL_C, TAB
export UP_ARROW, DOWN_ARROW, RIGHT_ARROW, LEFT_ARROW
export replay
export @deparse

# ---------------------------------------------------------------------------
# REPL modes (used by the ghostwriter)
#
# Prompt strings and colors are taken from the REPL stdlib itself (the
# `JULIA_PROMPT`/`SHELL_PROMPT`/`HELP_PROMPT` constants, the prompt colors
# stored on the `LineEditREPL` object and the pkg prompt generator), so the
# ghostwriter always matches the prompts of the running Julia version
# instead of a hardcoded copy that can drift out of sync with the stdlib.
# ---------------------------------------------------------------------------

struct GhostMode
    name::Symbol
    prompt::String
    prompt_prefix::String
    prompt_suffix::String
end

const _PROMPT_REPL = Ref{REPL.LineEditREPL}()

function _prompt_repl()
    # `Base.active_repl` is only bound while an interactive session is up.
    repl = isdefined(Base, :active_repl) ? Base.active_repl : nothing
    repl isa REPL.LineEditREPL && return repl
    if !isassigned(_PROMPT_REPL)
        # Not running inside an interactive session (e.g. a script or the
        # test suite): build a throwaway REPL on a dummy terminal purely as
        # the source of the stdlib's canonical prompt definitions, mirroring
        # how the real frontend constructs it.
        terminal = REPL.Terminals.TTYTerminal("dumb", IOBuffer(), IOBuffer(), IOBuffer())
        _PROMPT_REPL[] = REPL.LineEditREPL(terminal, Base.get_have_color(), true)
    end
    return _PROMPT_REPL[]
end

@static if isdefined(REPL, :Pkg_promptf)
    _pkg_prompt() = REPL.Pkg_promptf()
else
    # Older Julia versions keep the canonical prompt generator in Pkg.
    # Load it in this process too: setup_pty's `using Pkg` only affects the
    # child, and a bare REPL.PKG_PROMPT would lose the active project name.
    import Pkg
    _pkg_prompt() = Pkg.REPLMode.promptf()
end

function _pkg_prompt_prefix(repl::REPL.LineEditREPL)
    # Newer REPLs store the pkg prompt color on the REPL object; older ones
    # have no such field and Pkg's REPLMode used the blue text color instead.
    return hasfield(typeof(repl), :pkg_color) ? repl.pkg_color : Base.text_colors[:blue]
end

function ghost_mode(name::Symbol)
    repl = _prompt_repl()
    suffix = REPL.input_color(repl)
    if name === :shell
        return GhostMode(name, REPL.SHELL_PROMPT, repl.shell_color, suffix)
    elseif name === :help
        return GhostMode(name, REPL.HELP_PROMPT, repl.help_color, suffix)
    elseif name === :repl # pkg mode
        # The real pkg mode prints no prompt suffix.
        return GhostMode(name, _pkg_prompt(), _pkg_prompt_prefix(repl), "")
    end
    return GhostMode(:julian, REPL.JULIA_PROMPT, repl.prompt_color, suffix)
end

# Decide the mode a cell is displayed in. Returns a tuple of the mode, the
# script to type with the ghostwriter and the mode name that stays active
# for the next cell, or `nothing` when the previous mode simply continues.
# Return the mode that stays active after `cell`. Help mode is one-shot, so a
# leading `?` returns to Julia mode; Ctrl-C leaves a persistent shell/pkg mode.
# Shared by `_next_mode`, the splitter and the pre-flight check so they cannot
# drift apart.
function _advance_mode(cell::AbstractString, mode::Symbol)
    if mode === :julian
        c = isempty(cell) ? nothing : first(cell)
        c === ';' && return :shell
        c === ']' && return :repl
        return :julian
    elseif endswith(cell, CTRL_C)
        return :julian
    end
    return mode
end

function _next_mode(cell::AbstractString, current_mode_name::Symbol)
    next_mode_name = _advance_mode(cell, current_mode_name)
    if current_mode_name === :julian
        if next_mode_name === :shell
            # shell mode
            return ghost_mode(:shell), cell[begin+1:end], :shell
        elseif next_mode_name === :repl
            # pkg mode
            return ghost_mode(:repl), cell[begin+1:end], :repl
        elseif startswith(cell, '?')
            # help mode goes back to julian mode after the cell
            return ghost_mode(:help), cell[begin+1:end], :julian
        end
        return ghost_mode(:julian), cell, :julian
    elseif next_mode_name !== current_mode_name
        # back to julian mode
        return ghost_mode(:julian), cell, :julian
    end
    return nothing
end

# ---------------------------------------------------------------------------
# Splitting a script into REPL inputs
#
# The REPL does not split input on newlines. It accumulates lines and submits
# them once the parser stops reporting an incomplete expression: `REPL.jl`
# keeps reading while `Base.parse_input_line` returns an `Expr(:incomplete)`
# (`start_repl_backend`, and the prompt-paste path calls
# `Meta.parse(input, pos; raise=false)` for the same check). We follow that rule
# so a multi-line `function ... end` is replayed as one input.
#
# Cells are cut out of the original source instead of being re-printed from the
# parsed expression, which keeps comments, layout and trailing semicolons.
# ---------------------------------------------------------------------------

const _MODE_CHARS = (';', ']', '?', '\x03')

# A REPL mode command or a Ctrl-C, not Julia source. The REPL switches modes
# when one of these characters is typed at the start of an empty prompt (see
# the `';'`, `'?'` and `']'` keybindings in `REPL.jl`).
_is_mode_command(cell::AbstractString) = !isempty(cell) && first(cell) in _MODE_CHARS

# Remove the line separators and indentation that Replay adds back or does not
# need, while keeping meaningful terminal input. `strip` would delete a `\r`
# used to confirm a TerminalMenus selection and a trailing `\t` used for tab
# completion.
function _trim_input(s::AbstractString)
    start = firstindex(s)
    stop = lastindex(s)
    while start <= stop && (s[start] == '\n' || s[start] == ' ' || s[start] == '\t')
        start = nextind(s, start)
    end
    while start <= stop
        if s[stop] == '\n'
            stop = prevind(s, stop)
            continue
        end
        # Drop a trailing whitespace-only line, but keep spaces and tabs that
        # follow the last non-whitespace character on its line.
        j = stop
        while j >= start && (s[j] == ' ' || s[j] == '\t')
            j = prevind(s, j)
        end
        if j < start
            stop = start - 1
            break
        elseif s[j] == '\n'
            stop = j
            continue
        end
        break
    end
    return start <= stop ? String(SubString(s, start, stop)) : ""
end

# Arrow keys and menu confirmations arrive as raw terminal input rather than
# Julia source, so submit them as their own input.
function _is_keystroke(line::AbstractString)
    i = firstindex(line)
    stop = lastindex(line)
    while i <= stop && (line[i] == ' ' || line[i] == '\t')
        i = nextind(line, i)
    end
    i > stop && return false
    return line[i] == '\e' || line[i] == '\r'
end

# `Meta.parseall` represents a buffer holding only whitespace and comments as a
# `:toplevel` with just `LineNumberNode`s (or as `nothing`).
function _is_trivia(ast)
    ast === nothing ||
        (
            ast isa Expr && ast.head === :toplevel &&
            all(arg -> arg isa LineNumberNode, ast.args)
        )
end

function _incomplete_error(ast)
    err = ast isa Expr && !isempty(ast.args) ? ast.args[1] : ast
    return sprint(showerror, err)
end

function _split_instructions(src::AbstractString)
    cells = String[]
    buffer = ""
    incomplete = false
    mode = :julian
    for line in eachline(IOBuffer(String(src)); keep=true)
        if mode !== :julian
            # Shell and pkg modes submit one line at a time and stay active
            # until Ctrl-C returns to Julia mode, so do not feed their commands
            # to the Julia parser.
            cell = _trim_input(line)
            if !isempty(cell)
                push!(cells, cell)
                mode = _advance_mode(cell, mode)
            end
            continue
        end
        # A `;`, `]` or `?` at column 0 only switches REPL mode while the prompt
        # buffer is empty. Until a statement starts, `buffer` holds at most
        # blank lines and comments; replay those comments as their own no-op
        # input and keep the mode command separate. Raw keystrokes are never
        # Julia source and are submitted as their own input too.
        if !incomplete && (_is_mode_command(line) || _is_keystroke(line))
            comments = _trim_input(buffer)
            isempty(comments) || push!(cells, comments)
            cell = _trim_input(line)
            push!(cells, cell)
            mode = _advance_mode(cell, :julian)
            buffer = ""
            continue
        end
        buffer *= line
        ast = Base.parse_input_line(buffer; depwarn=false)
        if _is_trivia(ast)
            # No statement yet: keep accumulating so a leading comment stays
            # attached to the input that follows it. This also clears a pending
            # `:incomplete` from an unterminated block comment that just closed.
            incomplete = false
            continue
        elseif ast isa Expr && ast.head === :incomplete
            incomplete = true
            continue
        end
        cell = _trim_input(buffer)
        if !isempty(cell)
            push!(cells, cell)
            mode = _advance_mode(cell, mode)
        end
        buffer = ""
        incomplete = false
    end
    tail = _trim_input(buffer)
    if incomplete
        ast = Base.parse_input_line(buffer; depwarn=false)
        throw(
            ArgumentError(
                "the script ends with an incomplete input; add the missing `end`, " *
                "bracket or quote:\n" * _incomplete_error(ast),
            ),
        )
    elseif !isempty(tail)
        # A trailing comment is still part of the transcript, so replay it as a
        # no-op input instead of dropping it.
        push!(cells, tail)
    end
    return cells
end

function _check_complete(cell::AbstractString, index::Integer)
    ast = Base.parse_input_line(String(cell); depwarn=false)
    if ast isa Expr && ast.head === :incomplete
        throw(
            ArgumentError(
                "instruction $index is incomplete; the REPL would keep waiting for " *
                "more input. Join the remaining lines into the same instruction:\n" *
                _incomplete_error(ast),
            ),
        )
    end
    return nothing
end

# Reject incomplete instructions before the child REPL is started, so a typo
# does not leave the session waiting for the rest of an expression. Track modes
# because shell and pkg commands are not Julia source.
function _check_instructions(instructions)
    mode = :julian
    for (index, cell) in enumerate(instructions)
        if mode === :julian && !_is_mode_command(cell) && !endswith(cell, CTRL_C)
            _check_complete(cell, index)
        end
        mode = _advance_mode(cell, mode)
    end
    return nothing
end

# Recursively remove `LineNumberNode`s from `expr` in place. Unlike
# `Base.remove_linenums!`, this also clears the line-number slot of macro calls,
# so `string(expr)` does not contain `#= file:line =#` markers.
function _strip_linenums!(expr)
    expr isa Expr || return expr
    if expr.head === :macrocall &&
       length(expr.args) >= 2 &&
       expr.args[2] isa LineNumberNode
        # `Expr(:macrocall, ...)` reserves its second argument for the line
        # number, so deleting it would leave an invalid expression. `nothing`
        # keeps the shape valid and `show` omits it.
        expr.args[2] = nothing
    end
    filter!(arg -> !(arg isa LineNumberNode), expr.args)
    foreach(_strip_linenums!, expr.args)
    return expr
end

@doc raw"""
    @deparse expr

Return `expr` as a Julia source string using Julia's own printer, i.e.
`string(expr)`. `LineNumberNode`s are removed first, so the result contains no
`#= file:line =#` markers.

The macro does not try to reproduce the exact whitespace or syntax you typed;
it returns Julia's canonical representation of the parsed expression.

# Examples
```jldoctest
julia> @deparse 1+1
"1 + 1"

julia> @deparse sin(1f0+a)
"sin(1.0f0 + a)"

julia> @deparse f(x) = sin(x)/x
"f(x) = begin\n        sin(x) / x\n    end"
```
"""
macro deparse(expr)
    expr = deepcopy(expr)
    _strip_linenums!(expr)
    return string(expr)
end

function clearline(; move_up::Bool=false)
    buf = IOBuffer()
    print(buf, "\x1b[2K") # clear line
    print(buf, "\x1b[?25l") # hide cursor
    print(buf, "\x1b[999D") # rollback the cursor
    move_up && print(buf, "\x1b[1A") # move up
    print(buf |> take! |> String)
end

function clearlines(H::Integer)
    for _ in 1:H
        clearline(move_up=true)
    end
end

function type_with_ghost_core(line::AbstractString, mode; display_prompt=false)
    if !display_prompt
        # we assume we're in julian mode
        spacestring = " "
        dummy = repeat(spacestring, length("julia> "))
        line = dummy * line
    end
    clearline()
    for index in collect(eachindex(line))
        if display_prompt
            if Base.get_have_color()
                print(mode.prompt_prefix, mode.prompt, mode.prompt_suffix)
            else
                print(mode.prompt)
            end
        end
        println(join(line[begin:index]))
        clearline(move_up=true)
        duration = if 30 < length(line)
            0.0125
        elseif 15 < length(line) < 30
            0.05
        else
            0.1
        end
        sleep(duration)
    end
end

function type_with_ghost(repl_script::AbstractString, mode)
    lines = split(String(repl_script), '\n'; keepempty=false)
    H = length(lines)
    for (i, line) in enumerate(lines)
        display_prompt = (i == 1)
        type_with_ghost_core(line, mode; display_prompt)
        println()
    end
    clearlines(H)
end

# The Windows transport is a named pipe, not a real Cygwin terminal. Older
# Julia REPLs call `stty` on it when entering raw mode, which aborts startup.
# Override raw-mode switching only inside this dedicated child process;
# the parent Julia session and its real terminal are never modified.
const _REPL_STARTUP_WINDOWS = raw"""
        pushfirst!(LOAD_PATH, Sys.STDLIB)
        using REPL
        popfirst!(LOAD_PATH)
        @eval REPL.Terminals function raw!(t::TTYTerminal, raw::Bool)
            Base.check_open(t.in_stream)
            return true
        end
        print("\x1b[?25l")
        """

const _REPL_STARTUP_UNIX = raw"""print("\x1b[?25l")"""

function setup_pty(julia_project::AbstractString="@.", cmd::Cmd=`--color=yes`)
    pts, ptm = open_fake_pty()
    blackhole = Sys.isunix() ? "/dev/null" : "nul"
    julia_exepath = joinpath(Sys.BINDIR, Base.julia_exename())
    startup = Sys.iswindows() ? _REPL_STARTUP_WINDOWS : _REPL_STARTUP_UNIX
    replproc = withenv(
        "JULIA_HISTORY" => blackhole,
        "JULIA_PROJECT" => "$julia_project",
        "TERM" => "",
    ) do
        # Install packages
        run(`$(julia_exepath) -e 'using Pkg; Pkg.instantiate()'`)
        # Initialize REPL
        run(
            `$(julia_exepath) -i -e $startup $cmd`,
            pts,
            pts,
            pts;
            wait=false,
        )
    end
    Base.close_stdio(pts)
    return replproc, ptm
end

function _start_output_tee(ptm::IO, buf::IO)
    # Prepare a background process to copy output from process until `pts` is closed
    output_copy = Base.BufferStream()
    tee = @async try
        while !eof(ptm)
            l = readavailable(ptm)
            write(buf, l)
            Sys.iswindows() && (sleep(0.1); yield(); yield()) # workaround hang - probably a libuv issue?
            write(output_copy, l)
        end
        close(output_copy)
        close(ptm)
    catch ex
        close(output_copy)
        close(ptm)
        if !(ex isa Base.IOError && ex.code == Base.UV_EIO)
            rethrow() # ignore EIO on ptm after pts dies
        end
    end
    return output_copy, tee
end

function _send_cell(ptm::IO, cell::AbstractString)
    if endswith(cell, CTRL_C)
        write(ptm, cell)
        return
    end
    write(ptm, cell)
    # Multiline cells do not necessarily end with a newline (e.g. the output of
    # `@deparse`), but the REPL needs one to submit the input.
    endswith(cell, "\n") || write(ptm, "\n")
end

function _wait_for_next_prompt(output_copy::IO, prompt_delimiter::AbstractString)
    readuntil(output_copy, "\n")
    # wait for the next prompt-like to appear
    # NOTE: this is rather inaccurate because the Pkg REPL mode is a special flower
    readuntil(output_copy, "\n")
    readuntil(output_copy, prompt_delimiter)
end

@doc raw"""
    replay(instructions::Vector{<:AbstractString}, buf::IO; kwargs...)

Replay the REPL output from given instructions.

Each element of `instructions` is one complete input submitted to the REPL.
Multi-line inputs such as a `function ... end` definition must stay in a single
element. An instruction that the parser reports as incomplete raises an
`ArgumentError` before the child REPL is started. To replay a whole script,
pass it as a single string; see the `replay(script::AbstractString)` method.

## Keyword Arguments

### Replay options
- `use_ghostwriter`: Flag to enable ghostwriter mode. (default: `false`)

- `startup_prompt`: Text to wait for when the child REPL starts. (default: `"julia>"`)
- `prompt_delimiter`: Text ending each subsequent prompt. (default: `"> "`)
  For numbered prompts use `startup_prompt="In [1]: "`, `prompt_delimiter="]: "`,
  and leave `use_ghostwriter=false`; ghostwriter assumes the standard prompts.

### Julia options
- `julia_project`: Path to a project where julia process runs. (default: `@.`)
- `cmd`: Additional command for julia process. (default: `"--color=yes"`)

### Numbered prompts

Initialize Julia's REPL interface before enabling numbered prompts:

```julia
replay(["1 + 1", "ans * 2"];
    cmd=`-q --color=no -e 'using REPL; atreplinit(repl -> (repl.interface = REPL.setup_interface(repl); REPL.numbered_prompt!(repl)))'`,
    startup_prompt="In [1]: ", prompt_delimiter="]: ")
```

### Interactive menus

ASCII `REPL.TerminalMenus` menus can be replayed with the default prompt delimiter.
Put the request and its response in separate instructions and use a carriage return
(`"\r"`) to confirm a selection:

```julia
replay([
    "using REPL.TerminalMenus",
    "menu = RadioMenu([\"apple\", \"orange\"]);",
    "choice = request(\"Choose fruit:\", menu)",
    "$(DOWN_ARROW)\r",
    "@show choice",
])
```

Use `"q"` to cancel a TerminalMenus request. Menu requests must display the configured
`prompt_delimiter`; arbitrary full-screen TUIs or menus with different cursor styles
are not automatically detected. Keep `use_ghostwriter=false` for raw menu keystrokes.

"""
function replay(
    instructions::Vector{<:AbstractString},
    buf::IO=stdout;
    use_ghostwriter=false,
    julia_project="@.",
    cmd::Cmd=`--color=yes`,
    startup_prompt::AbstractString="julia>",
    prompt_delimiter::AbstractString="> ",
)
    isempty(startup_prompt) && throw(ArgumentError("startup_prompt must not be empty"))
    isempty(prompt_delimiter) && throw(ArgumentError("prompt_delimiter must not be empty"))
    if use_ghostwriter && (startup_prompt != "julia>" || prompt_delimiter != "> ")
        throw(ArgumentError("custom prompts require use_ghostwriter=false"))
    end
    _check_instructions(instructions)
    print("\x1b[?25l") # hide cursor
    replproc, ptm = setup_pty(julia_project, cmd)
    output_copy, tee = _start_output_tee(ptm, buf)
    # wait for the definitive prompt before start writing to the TTY
    readuntil(output_copy, startup_prompt)
    sleep(0.1)
    readavailable(output_copy)

    mode = ghost_mode(:julian)
    current_mode_name = :julian

    # let's replay!
    for cell in instructions
        sleep(1)

        transition = _next_mode(cell, current_mode_name)
        ghost_script = cell
        if transition !== nothing
            mode, ghost_script, current_mode_name = transition
        end

        bytesavailable(output_copy) > 0 && readavailable(output_copy)

        use_ghostwriter && type_with_ghost(ghost_script, mode)

        _send_cell(ptm, cell)
        _wait_for_next_prompt(output_copy, prompt_delimiter)
    end

    sleep(1)
    use_ghostwriter && type_with_ghost("exit()", mode)
    if current_mode_name === :julian
        write(ptm, "exit()\n")
    else
        write(ptm, "\bexit()\n")
    end
    sleep(1)
    wait(tee)
    success(replproc) || Base.pipeline_error(replproc)
    close(ptm)
    print("\x1b[?25h") # unhide
    return buf
end

"""
    replay(script::AbstractString, buf::IO=stdout; kwargs...)

Split `script` into REPL inputs and replay them.

Splitting uses the REPL's own completeness rule: lines are accumulated until
`Base.parse_input_line` no longer returns an `Expr(:incomplete)`, so a
multi-line definition is submitted as one input. Lines that start with `;`,
`]` or `?` at column 0 are treated as shell, pkg and help mode commands, and a
line starting with a Ctrl-C character interrupts the current mode.

The script must be complete. If it ends in the middle of an expression, an
`ArgumentError` is raised instead of leaving the child REPL waiting for input.
"""
function replay(repl_script::AbstractString, args...; kwargs...)
    replay(_split_instructions(repl_script), args...; kwargs...)
end

end # module
