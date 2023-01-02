using Replay

i1 = @inst println("Hello World")
i2 = @inst using LinearAlgebra
i3 = @inst begin
    x = [1, 1]
    A = [1 0; 0 2]
end
i4 = @inst @show dot(x, A, x)
i5 = @inst function f(x)
    @comment This is a comment
    if x > 0
        @comment x is larger than 0
        @info "x is larger than 0"
    end
    @info "compute 2x + 2"
    2x + 2
end
i6 = @inst x = 3
i7 = @inst f(x)

replay([i1, i2, i3, i4, i5, i6, i7], use_ghostwriter=true)
