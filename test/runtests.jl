using Replay
using Test

ENV["CI"] = "true"

const repl_script = """
2+2
print("")
display([1])
display([1 2; 3 4])
"""

for color in [:yes, true]
    @testset "replay: color=$color" begin
        buf = replay(repl_script, IOBuffer(); color, cmd = "-q")
        out = buf |> take! |> String
        #=
        open(joinpath(@__DIR__, "references", "replay_color_$(color)_julia.txt"), "w") do f
            write(f, out)
        end
        =#
        reftxt = joinpath(@__DIR__, "references", "replay_color_yes_julia.txt")
        ref = join(readlines(reftxt), "\r\n")
        @test out == ref
    end
end

for color in [:no, false]
    @testset "replay: color=no" begin
        buf = replay(repl_script, IOBuffer(), color = :no, cmd = "-q")
        out = buf |> take! |> String
        #=
        open(joinpath(@__DIR__, "references", "replay_color_$(color)_julia.txt"), "w") do f
            write(f, out)
        end
        =#
        reftxt = joinpath(@__DIR__, "references", "replay_color_no_julia.txt")
        ref = join(readlines(reftxt), "\r\n")
        @test out == ref
    end
end

examples_dir = joinpath(pkgdir(Replay), "examples")
for example in readdir(examples_dir)
    @testset "$example" begin
        apppath = joinpath(examples_dir, example, "app.jl")
        julia_exepath = joinpath(Sys.BINDIR::String, Base.julia_exename())
        @info "running $(example)"
        withenv("CI" => true) do
            r = run(`$(julia_exepath) $(apppath)`)
            @test r.exitcode == 0
        end
    end
end
