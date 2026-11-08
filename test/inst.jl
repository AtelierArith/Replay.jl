@testset "@deparse 1" begin
    ref = "1"
    tar = @deparse 1
    @test tar == ref
end

@testset "@deparse @show x" begin
    ref = "@show x"
    tar = @deparse @show x
    @test tar == ref
end

@testset "@deparse println(\"Hello World\")" begin
    ref = "println(\"Hello World\")"
    tar = @deparse println("Hello World")
    @test tar == ref
end

@testset "using LinearAlgebra: dot" begin
    ref = "using LinearAlgebra: dot"
    tar = @deparse using LinearAlgebra: dot
    @test tar == ref
end

# `@deparse` returns Julia's canonical `string(expr)`, not the exact source the
# user typed. Short-form definitions therefore contain an explicit block.
@testset "f(x) = x" begin
    ref = "f(x) = begin\n        x\n    end"
    tar = @deparse f(x) = x
    @test tar == ref
end

@testset "anonymous function" begin
    ref = "x->begin\n        x ^ 2\n    end"
    tar = @deparse x -> x^2
    @test tar == ref
end

@testset "function definition" begin
    ref = "function f(x)\n    y = 2x + 1\n    z = y ^ 3\n    return y\nend"
    tar = @deparse function f(x)
        y = 2x + 1
        z = y^3
        return y
    end
    @test ref == tar
end

@testset "@comment is left as a macro call" begin
    ref = "function f(x)\n    @comment linear transformation\n    y = 2x\n    @comment square root of y\n    z = √y\n    return y\nend"
    tar = @deparse function f(x)
        @comment linear transformation
        y = 2x
        @comment square root of y
        z = √y
        return y
    end
    @test tar == ref
end

@testset "nested @comment and macros" begin
    ref = "function f(x)\n    @comment This is a comment\n    if x > 0\n        @comment x is larger than 0\n        @info \"x is larger than 0\"\n    end\n    @info \"compute 2x + 2\"\n    2x + 2\nend"
    tar = @deparse function f(x)
        @comment This is a comment
        if x > 0
            @comment x is larger than 0
            @info "x is larger than 0"
        end
        @info "compute 2x + 2"
        2x + 2
    end
    @test tar == ref
end

# Regression test: an `@` inside a string literal used to make the old
# line-based rewriting throw a `BoundsError` at macro expansion time.
@testset "@ inside a string literal" begin
    ref = "function f(x)\n    s = \"email@example.com\"\n    return length(s)\nend"
    tar = @deparse function f(x)
        s = "email@example.com"
        return length(s)
    end
    @test tar == ref
end

@testset "no line number markers" begin
    tar = @deparse function f(x)
        @show x
        return x
    end
    @test !occursin("#=", tar)
    @test occursin("@show x", tar)
end
