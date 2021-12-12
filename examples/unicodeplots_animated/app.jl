using Replay

lemma = joinpath(@__DIR__, "lemma.jl")

instructions = """
include("$lemma");
frames = [lineplot(x -> sin(x - t), width = 40) for t = -π:0.25π:π];
animate(frames)
"""

replay(instructions; julia_project=@__DIR__, use_ghostwriter=true)
