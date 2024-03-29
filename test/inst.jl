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

# We don't support the expression yet.
@testset "f(x) = x" begin
    ref = "f(x) = x"
    tar = @deparse f(x) = x
    @test_broken tar == ref
end

@testset "function definition" begin
    ref = """
    function f(x)
        y = 2x + 1
        z = y ^ 3
        return y
    end
    """
    tar = @deparse function f(x)
        y = 2x + 1
        z = y^3
        return y
    end
    @test ref == tar
end

@testset "function definition with comments" begin
    ref = """
    function f(x)
        # linear transformation
        y = 2x
        # square root of y
        z = √y
        return y
    end
    """
    tar = @deparse function f(x)
        @comment linear transformation
        y = 2x
        @comment square root of y
        z = √y
        return y
    end
    @test ref == tar
end

@testset "@comment" begin
    ref = """
    function f(x)
        # This is a comment
        if x > 0
            # x is larger than 0
            @info "x is larger than 0"
        end
        @info "compute 2x + 2"
        2x + 2
    end
    """
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
