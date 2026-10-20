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
    buf = IOBuffer()
    try
        replay(repl_script, buf; cmd=`-q --color=yes`)
    catch
        @error "Captured REPL output" output = String(take!(buf))
        rethrow()
    end
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
    if isfile(reftxt) && !Sys.iswindows()
        ref = join(readlines(reftxt), "\r\n")
        @test out == ref
    else
        # Terminal escape sequences change across Julia versions and platforms.
        plain = replace(out, r"\e\[[0-?]*[ -/]*[@-~]" => "")
        @test occursin(r"(?m)^Hello World\r?$", plain)
        @test occursin(r"(?m)^x = 2\r?$", plain)
        @test occursin("julia>", out)
    end
end

@testset "replay: color=no" begin
    color = "no"
    buf = IOBuffer()
    try
        replay(repl_script, buf; cmd=`-q --color=no`)
    catch
        @error "Captured REPL output" output = String(take!(buf))
        rethrow()
    end
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
    if isfile(reftxt) && !Sys.iswindows()
        ref = join(readlines(reftxt), "\r\n")
        @test out == ref
    else
        # Terminal escape sequences change across Julia versions and platforms.
        plain = replace(out, r"\e\[[0-?]*[ -/]*[@-~]" => "")
        @test occursin(r"(?m)^Hello World\r?$", plain)
        @test occursin(r"(?m)^x = 2\r?$", plain)
        @test occursin("julia>", out)
    end
end

include("inst.jl")

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

include("recordings.jl")

if Sys.iswindows()
    @testset "Windows retains LineEdit tab completion" begin
        buf = replay(
            ["\\alpha$(TAB) = 7", "?nothing", "@show α"],
            IOBuffer();
            cmd=`-q --color=no`,
        )
        plain = replace(String(take!(buf)), r"\e\[[0-?]*[ -/]*[@-~]" => "")
        @test occursin(r"(?m)^α = 7\r?$", plain)
    end
end
