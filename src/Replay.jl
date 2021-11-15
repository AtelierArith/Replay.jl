module Replay

include("FakePTYs.jl")
using .FakePTYs: open_fake_pty

const CTRL_C = '\x03'
const UP_ARROW = "\e[A"
const DOWN_ARROW = "\e[B"
const RIGHT_ARROW = "\e[C"
const LEFT_ARROW = "\e[D"

export CTRL_C, UP_ARROW, DOWN_ARROW, RIGHT_ARROW, LEFT_ARROW
export replay

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
        "JULIA_PROJECT" => nothing, # remove from environment
        "JULIA_LOAD_PATH" => Sys.iswindows() ? "@;@stdlib" : "@:@stdlib",
        "JULIA_PKG_PRECOMPILE_AUTO" => "0",
        "TERM" => ""
    ) do
        run(
            ```$(julia_exepath) -O0
                --cpu-target=native --startup-file=no --color=$(color)
                -e 'import REPL; REPL.Terminals.is_precompiling[] = true'
                -i ```,
            pts, pts, pts; wait = false
        )
    end
    Base.close_stdio(pts)
    return replproc, ptm
end

replay(repl_script::String, buf::IO = stdout; color = :yes) = replay(split(repl_script::String, '\n'; keepempty = false), buf; color)

function replay(repl_lines::Vector{T}, buf::IO = stdout; color = :yes) where {T<:AbstractString}
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
    println()
    write(ptm, "exit()\n")
    wait(tee)
    success(replproc) || Base.pipeline_error(replproc)
    close(ptm)
    return buf
end

end # module