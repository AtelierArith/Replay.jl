using Replay

lemma = joinpath(@__DIR__, "lemma.jl")

instructions = [
    "using UnicodePlots",
    raw"""
    function clearline(; move_up::Bool = false)
        buf = IOBuffer()
        print(buf, "\x1b[2K") # clear line
        print(buf, "\x1b[999D") # rollback the cursor
        move_up && print(buf, "\x1b[1A") # move up
        print(buf |> take! |> String)
    end
    """,
    raw"""
    function clearlines(H::Integer)
        for i = 1:H
            clearline(move_up = true)
        end
    end
    """,
    raw"""
    function animate(frames::Vector{<:UnicodePlots.Plot}; duration::Float64 = 0.5)
        print("\x1b[?25l") # hidecursor
        for (n, f) in enumerate(frames)
            print(f)
            str = string(f)
            if n != length(frames)
                sleep(duration)
                clearlines(length(collect(eachmatch(r"\n", str))))
            end
        end
        print("\u001B[?25h") # unhide cursor
    end
    """,
    "frames = [lineplot(x -> sin(x - t), width = 40) for t = -2π:0.25π:2π];",
    "animate(frames)",
]

replay(instructions; julia_project=@__DIR__, use_ghostwriter=false)
