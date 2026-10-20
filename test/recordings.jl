include(joinpath(@__DIR__, "..", "docs", "recordings.jl"))

@testset "documentation recordings" begin
    mktempdir() do dir
        path = joinpath(dir, "example.cast")
        calls = Symbol[]
        runner = function (command)
            push!(calls, command)
            command == :record && write(path, "recording")
        end

        # A clean checkout must create the missing recording, even with caching on.
        ensure_recording(path, :warmup, :record; runner)
        @test calls == [:warmup, :record]
        @test isfile(path)

        empty!(calls)
        ensure_recording(path, :warmup, :record; runner)
        @test isempty(calls)

        ensure_recording(path, :warmup, :record; runner, skip_existing_cast=false)
        @test calls == [:warmup, :record]

        rm(path)
        @test_throws ErrorException ensure_recording(
            path, :warmup, :record; runner=command -> nothing,
        )
    end
end
