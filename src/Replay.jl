module Replay

using Crayons

include("FakePTYs.jl")
using .FakePTYs: open_fake_pty

const CTRL_C = '\x03'
const UP_ARROW = "\e[A"
const DOWN_ARROW = "\e[B"
const RIGHT_ARROW = "\e[C"
const LEFT_ARROW = "\e[D"

export CTRL_C, UP_ARROW, DOWN_ARROW, RIGHT_ARROW, LEFT_ARROW
export replay

function clearline(; move_up::Bool = false)
    buf = IOBuffer()
    print(buf, "\x1b[2K") # clear line
    print(buf, "\x1b[999D") # rollback the cursor
    move_up && print(buf, "\x1b[1A") # move up
    print(buf |> take! |> String)
end

function clearlines(H::Integer)
    for i = 1:H
        clearline(move_up = true)
    end
end

function type_with_ghost_core(line::AbstractString, mode; display_prompt = false)
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
        clearline(move_up = true)
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
    lines = split(String(repl_script), '\n'; keepempty = false)
    H = length(lines)
    for (i, line) in enumerate(lines)
        display_prompt = (i == 1)
        type_with_ghost_core(line, mode; display_prompt)
        println()
    end
    clearlines(H)
end

function setup_pty(julia_project = "@."::AbstractString, cmd = String = "--color=yes")
    pts, ptm = open_fake_pty()
    blackhole = Sys.isunix() ? "/dev/null" : "nul"
    julia_exepath = joinpath(Sys.BINDIR::String, Base.julia_exename())
    replproc = withenv(
        "JULIA_HISTORY" => blackhole,
        "JULIA_PROJECT" => "$julia_project",
        "TERM" => "",
    ) do
        # Install packages
        run(`$(julia_exepath) -e 'using Pkg; Pkg.instantiate()'`)
        # Initialize REPL
        run(```$(julia_exepath) $(split(cmd))```, pts, pts, pts; wait = false)
    end
    Base.close_stdio(pts)
    return replproc, ptm
end

function replay(
    instructions::Vector{<:AbstractString},
    buf::IO = stdout;
    use_ghostwriter = false,
    julia_project = "@.",
    cmd = String = "--color=yes",
)
    print("\x1b[?25l") # hide cursor
    replproc, ptm = setup_pty(julia_project, cmd)
    # Prepare a background process to copy output from process until `pts` is closed
    output_copy = Base.BufferStream()
    tee = @async try
        while !eof(ptm)
            # using `stdout` rather than `buf` is intentionally designed
            write(stdout, "\x1b[?25l") # hide cursor
            l = readavailable(ptm)
            write(buf, l)
            Sys.iswindows() && (sleep(0.1); yield(); yield()) # workaround hang - probably a libuv issue?
            write(output_copy, l)
        end
        # using `stdout` rather than `buf` is intentionally designed
        write(stdout, "\x1b[?25h") # unhide cursor
        close(output_copy)
        close(ptm)
    catch ex
        close(output_copy)
        close(ptm)
        if !(ex isa Base.IOError && ex.code == Base.UV_EIO)
            rethrow() # ignore EIO on ptm after pts dies
        end
    end
    # wait for the definitive prompt before start writing to the TTY
    readuntil(output_copy, "julia>")
    sleep(0.1)
    readavailable(output_copy)

    name = :julian
    prompt = "julia> "
    prompt_prefix = Base.text_colors[:bold] * Base.text_colors[:green]
    prompt_suffix = Base.color_normal
    mode = (; name, prompt, prompt_prefix, prompt_suffix)
    current_mode_name = :julian

    # let's replay!
    for cell in instructions
        sleep(1)

        ghost_script = cell
        if current_mode_name == :julian
            mode = if startswith(cell, ';')
                ghost_script = cell[begin+1:end] # remove ';'
                # shell mode
                name = :shell
                prompt = "shell> "
                prompt_prefix = Base.text_colors[:bold] * Base.text_color[:red]
                prompt_suffix = Base.color_normal
                current_mode_name = name
                (; name, prompt, prompt_prefix, prompt_suffix)
            elseif startswith(cell, ']')
                ghost_script = cell[begin+1:end] # remove ']'
                # pkg repl
                name = :repl
                prompt_prefix = Base.text_colors[:bold] * Base.text_colors[:blue]
                active_project_dir, _ =
                    splitext(Base.active_project() |> dirname |> basename)
                if occursin(r"v[0-9].[0-9]", active_project_dir)
                    prompt = "(@v$(VERSION.major).$(VERSION.minor)) pkg> "
                else
                    prompt = "($(active_project_dir)) pkg> "
                end
                prompt_suffix = Base.color_normal
                current_mode_name = name
                (; name, prompt, prompt_prefix, prompt_suffix)
            elseif startswith(cell, '?')
                ghost_script = cell[begin+1:end] # remove '?'
                # help mode
                name = :help
                prompt = "help?> "
                prompt_prefix = Base.text_colors[:bold] * Base.text_colors[:yellow]
                prompt_suffix = Base.color_normal
                # help mode should back to julian mode
                current_mode_name = :julian
                (; name, prompt, prompt_prefix, prompt_suffix)
            else
                # julian mode
                name = :julian
                prompt = "julia> "
                prompt_prefix = Base.text_colors[:bold] * Base.text_colors[:green]
                prompt_suffix = Base.color_normal
                current_mode_name = :julian
                (; name, prompt, prompt_prefix, prompt_suffix)
            end
        else
            if endswith(cell, CTRL_C)
                # julian mode
                name = :julian
                prompt = "julia> "
                prompt_prefix = Base.text_colors[:bold] * Base.text_colors[:green]
                prompt_suffix = Base.color_normal
                current_mode_name = :julian
                mode = (; name, prompt, prompt_prefix, prompt_suffix)
            end
        end

        bytesavailable(output_copy) > 0 && readavailable(output_copy)

        use_ghostwriter && type_with_ghost(ghost_script, mode)

        if endswith(cell, CTRL_C)
            write(ptm, cell)
        else
            if length(split(string(cell), '\n'; keepempty = false)) == 1
                write(ptm, cell, "\n")
            else
                write(ptm, cell)
            end
        end
        readuntil(output_copy, "\n")
        # wait for the next prompt-like to appear
        # NOTE: this is rather inaccurate because the Pkg REPL mode is a special flower
        readuntil(output_copy, "\n")
        readuntil(output_copy, "> ")
    end

    sleep(1)
    use_ghostwriter && type_with_ghost("exit()", mode)
    write(ptm, "exit()\n")
    sleep(1)
    wait(tee)
    success(replproc) || Base.pipeline_error(replproc)
    close(ptm)
    print("\x1b[?25h") # unhide
    return buf
end

replay(repl_script::AbstractString, args...; kwargs...) =
    replay(split(String(repl_script), '\n'; keepempty = false), args...; kwargs...)

end # module
