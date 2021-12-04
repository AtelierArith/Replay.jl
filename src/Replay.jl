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

function type_with_ghost(line::AbstractString)
    juliaprompt = "julia> "
    clearline()
    for index in collect(eachindex(line))
        print(crayon"green bold", juliaprompt)
        print(crayon"reset")
        println(join(line[begin:index]))
        clearlines(1)
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

function setup_pty(color = :yes; julia_project = "@."::AbstractString, cmd::String = "")
    if color in [:yes, true]
        color = "yes"
    else
        color = "no"
    end
    pts, ptm = open_fake_pty()
    blackhole = Sys.isunix() ? "/dev/null" : "nul"
    julia_exepath = joinpath(Sys.BINDIR::String, Base.julia_exename())
    replproc = withenv(
        "JULIA_HISTORY" => blackhole,
        "JULIA_PROJECT" => "$julia_project",
        "CI" => get(ENV, "CI", "false"),
        "TERM" => ""
    ) do
        # MyNote
        # -e 'if ENV["CI"] != ... ' is required to pass Pkg.test(), or "IOError: stream is closed or unusable" will happen.
        # idk why we need print("\x1b[?25l") inside of -e '...'
        # It seems print("\x1b[?25l") inside of the replay function does not work???
        run(
            ```$(julia_exepath)
                --cpu-target=native --startup-file=no --color=$(color)
                -e 'if ENV["CI"] != "true"; using Pkg; Pkg.instantiate(); print("\x1b[?25l"); end'
                -i
                $(cmd)
            ```,
            pts, pts, pts; wait = false
        )
    end
    Base.close_stdio(pts)
    return replproc, ptm
end

function replay(repl_lines::Vector{<:AbstractString}, buf::IO = stdout; color = :yes, use_ghostwriter = false, julia_project = "@.", cmd::String="")
    # c.f. MyNote above
    print("\x1b[?25l") # hide cursor
    replproc, ptm = setup_pty(color; julia_project, cmd)
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
    # wait for the definitive prompt before start writing to the TTY
    readuntil(output_copy, "julia>")
    sleep(0.1)
    readavailable(output_copy)

    # let's replay!
    for line in repl_lines
        sleep(1)
        bytesavailable(output_copy) > 0 && readavailable(output_copy)

        use_ghostwriter && type_with_ghost(line)

        if endswith(line, "\x03")
            write(ptm, line)
        else
            write(ptm, line, "\n")
        end
        readuntil(output_copy, "\n")
        # wait for the next prompt-like to appear
        # NOTE: this is rather inaccurate because the Pkg REPL mode is a special flower
        readuntil(output_copy, "\n")
        readuntil(output_copy, "> ")
    end

    sleep(1)
    use_ghostwriter && type_with_ghost("exit()")
    write(ptm, "exit()\n")
    sleep(1)
    wait(tee)
    success(replproc) || Base.pipeline_error(replproc)
    close(ptm)
    print("\x1b[?25h") # unhide
    return buf
end

replay(repl_script::String, buf::IO = stdout; color = :yes, use_ghostwriter = false, julia_project = "@.", cmd::String="") = replay(split(repl_script::String, '\n'; keepempty = false), buf; color, use_ghostwriter, julia_project, cmd)

end # module