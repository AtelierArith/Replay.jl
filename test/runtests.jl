using Replay
using Test

const repl_script = """
2+2
print("")
display([1])
display([1 2; 3 4])
@time 1+1
"""

@testset "replay: color=yes" begin
    buf = replay(repl_script, IOBuffer()) # color=:yes by default
    out = buf |> take! |> String
    #=
    open(joinpath(@__DIR__, "references", "replay_color_yes.txt"), "w") do f
        write(f, out)
    end
    =#
    reftxt = joinpath(@__DIR__, "references", "replay_color_yes.txt")
    ref = join(readlines(reftxt), "\r\n")
    @test out == ref
end

@testset "replay: color=true" begin
    buf = replay(repl_script, IOBuffer(), color = true)
    out = buf |> take! |> String
    reftxt = joinpath(@__DIR__, "references", "replay_color_yes.txt")
    ref = join(readlines(reftxt), "\r\n")
    @test out == ref
end

@testset "replay: color=no" begin
    buf = replay(repl_script, IOBuffer(), color = :no)
    out = buf |> take! |> String
    #=
    open(joinpath(@__DIR__, "references", "replay_color_no.txt"), "w") do f
        write(f, out)
    end
    =#
    reftxt = joinpath(@__DIR__, "references", "replay_color_no.txt")
    ref = join(readlines(reftxt), "\r\n")
    @test out == ref
end

@testset "replay: color=false" begin
    buf = replay(repl_script, IOBuffer(), color = false)
    out = buf |> take! |> String
    reftxt = joinpath(@__DIR__, "references", "replay_color_no.txt")
    ref = join(readlines(reftxt), "\r\n")
    @test out == ref
end
