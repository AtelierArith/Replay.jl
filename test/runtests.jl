using Replay
using Test

const repl_script = """
x = 1 + 1
println("Hello World")
@show x
"""

# Set false for daily use.
const UPDATE_REFERENCE = false

# Inspired by 
# https://github.com/JuliaPlots/Plots.jl/blob/master/test/runtests.jl#L38
is_ci() = parse(Bool, get(ENV, "CI", "false"))

if is_ci()
    @testset "check UPDATE_REFERENCE is false in CI" begin
        @test UPDATE_REFERENCE == false
    end
end

version_dir = "v$(VERSION.major).$(VERSION.minor)"

mkpath(joinpath(@__DIR__, "references", version_dir))

@testset "replay: color=yes" begin
    color = "yes"
    buf = replay(repl_script, IOBuffer(); cmd="-q --color=yes")
    out = buf |> take! |> String

    UPDATE_REFERENCE && open(
        joinpath(
            @__DIR__,
            "references",
            version_dir,
            "replay_color_$(color)_julia.txt",
        ),
        "w",
    ) do f
        write(f, out)
    end

    reftxt = joinpath(@__DIR__, "references", version_dir, "replay_color_yes_julia.txt")
    ref = join(readlines(reftxt), "\r\n")
    @test out == ref
end

@testset "replay: color=no" begin
    color = "no"
    buf = replay(repl_script, IOBuffer(); cmd="-q --color=no")
    out = buf |> take! |> String

    UPDATE_REFERENCE && open(
        joinpath(
            @__DIR__,
            "references",
            version_dir,
            "replay_color_$(color)_julia.txt",
        ),
        "w",
    ) do f
        write(f, out)
    end

    reftxt = joinpath(@__DIR__, "references", version_dir, "replay_color_no_julia.txt")
    ref = join(readlines(reftxt), "\r\n")
    @test out == ref
end

#=
using Replay, Test
endexamples_dir = joinpath(pkgdir(Replay), "examples")
examples_dir = joinpath(pkgdir(Replay), "examples")
for example in readdir(examples_dir)
    example == "disable_color" && continue
    @testset "$example" begin
        apppath = joinpath(examples_dir, example, "app.jl")
        julia_exepath = joinpath(Sys.BINDIR::String, Base.julia_exename())
        @info "running $(example)"
        r = run(`$(julia_exepath) $(apppath)`)
        @test r.exitcode == 0
    end
end
=#
