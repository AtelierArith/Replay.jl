#=
Inspired by David Neuzerling-san's blog post [Animated Unicode Plots with Julia](https://mdneuzerling.com/post/animated-unicode-plots-with-julia/)
=#

using UnicodePlots
using SparseArrays: sprandn

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
