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

function clearline(;move_up::Bool=false)
    buf = IOBuffer()
    print(buf, "\x1b[2K") # clear line
    print(buf, "\x1b[999D") # rollback the cursor
    move_up && print(buf, "\x1b[1A") # move up
    print(buf |> take! |> String)
end

function clearlines(H::Integer)
    for i in 1:H
        clearline(move_up=true)
    end
end

function setup_pty(color = :yes)
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
        "JULIA_PROJECT" => "@.",
        "TERM" => ""
    ) do
        run(
            ```$(julia_exepath)
                --cpu-target=native --startup-file=no --color=$(color)
                -i ```,
            pts, pts, pts; wait = false
        )
    end
    Base.close_stdio(pts)
    return replproc, ptm
end

function type_with_ghost(line::AbstractString)
    juliaprompt = "julia> "
    clearline()
    for index in collect(eachindex(line))
        print(crayon"green bold", juliaprompt)
        print(crayon"reset")
        println(join(line[begin:index]))
        clearlines(1)
        sleep(0.1)
    end
end

replay(repl_script::String, buf::IO = stdout; color = :yes, ghost_mode=false) = replay(split(repl_script::String, '\n'; keepempty = false), buf; color, ghost_mode)

function replay(repl_lines::Vector{T}, buf::IO = stdout; color = :yes, ghost_mode=false) where {T<:AbstractString}
    print("\x1b[?25l") # hide cursor
    replproc, ptm = setup_pty(color)
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
    for line in repl_lines
        sleep(1)
        bytesavailable(output_copy) > 0 && readavailable(output_copy)

        ghost_mode && type_with_ghost(line)

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
    ghost_mode && type_with_ghost("exit()")
    write(ptm, "exit()\n")
    sleep(1)
    wait(tee)
    success(replproc) || Base.pipeline_error(replproc)
    close(ptm)
    print("\x1b[?25h") # unhide
    return buf
end

end # module