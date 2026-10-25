using Documenter

# Build with make.jl first. Publication is an explicit, separate operation.
deploydocs(; repo="github.com/AtelierArith/Replay.jl", devbranch="main", push_preview=true)
