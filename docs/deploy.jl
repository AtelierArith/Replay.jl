using Documenter

# Build with make.jl first. Publication is an explicit, separate operation.
isfile(joinpath(@__DIR__, "build", "index.html")) ||
    error("Build documentation with docs/make.jl before deployment")

deploydocs(;
    root=@__DIR__,
    repo="github.com/AtelierArith/Replay.jl",
    devbranch="main",
    push_preview=true,
)
