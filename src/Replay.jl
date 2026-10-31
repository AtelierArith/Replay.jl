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

function _pkg_prompt()
    if isdefined(REPL, :Pkg_promptf)
        return REPL.Pkg_promptf()
    end
    # Older Julia versions keep the pkg prompt generator in Pkg's REPLMode,
    # which is only reachable when Pkg has already been loaded.
    pkg_id = Base.PkgId(Base.UUID("44cfe95a-1eb2-52ea-b672-e2afdf69b78f"), "Pkg")
    pkg = get(Base.loaded_modules, pkg_id, nothing)
    if pkg !== nothing && isdefined(pkg, :REPLMode)
        return pkg.REPLMode.promptf()
    end
    return REPL.PKG_PROMPT
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
function _next_mode(cell::AbstractString, current_mode_name::Symbol)
    if current_mode_name === :julian
        if startswith(cell, ';')
            # shell mode
            return ghost_mode(:shell), cell[begin+1:end], :shell
        elseif startswith(cell, ']')
            # pkg mode
            return ghost_mode(:repl), cell[begin+1:end], :repl
        elseif startswith(cell, '?')
            # help mode goes back to julian mode after the cell
            return ghost_mode(:help), cell[begin+1:end], :julian
        end
        return ghost_mode(:julian), cell, :julian
    elseif endswith(cell, CTRL_C)
        # back to julian mode
        return ghost_mode(:julian), cell, :julian
    end
    return nothing
end

@doc raw"""
    @deparse expr
Create a string from `expr`. It tries to output something similar to we type in Julia REPL.
If `expr` contains `@comment <message>`, it is transformed into `# <message>`.

# Examples
```jldoctest
julia> @deparse 1+1
"1 + 1"

julia> @deparse sin(1f0+a)
"sin(1.0f0 + a)"

julia> @deparse f(x) = sin(x)/x  # Sometimes not work as expected
"f(x) = begin\n        sin(x) / x\n    end\n"
```
"""
macro deparse(expr)
    Base.remove_linenums!(expr)
    lines = map(_deparse_line, split(string(expr), "\n"))
    text = join(lines, "\n")
    return length(lines) > 1 ? text * "\n" : text
end

function _deparse_line(w::AbstractString)
    # check that line `w` contains a macro expression
    m = match(r"@", w)
    if isnothing(m)
        return w
    end
    # Here string object `w` has a form of "<indent>#= ... =# @<macro> ..."
    # extract <indent>
    indent = replace(
        w[begin:match(r"\s?#|$", w).offset],
        "#" => "", # remove `#`
    )
    # remove `#= ... =#`
    # If `@<macro>` is equal to `@comment`, we replace `@<macro>` with `#`.
    return indent * replace(w[m.offset:end], "@comment" => "#")
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
    elseif length(split(string(cell), '\n'; keepempty=false)) == 1
        write(ptm, cell, "\n")
    else
        write(ptm, cell)
    end
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

function replay(repl_script::AbstractString, args...; kwargs...)
    replay(split(String(repl_script), '\n'; keepempty=false), args...; kwargs...)
end

end # module
