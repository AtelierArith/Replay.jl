using Replay

instructions = """
using OhMyREPL
using RDatasets, StatsPlots

unicodeplots();
iris = dataset("datasets", "iris");
@show names(iris);
@df iris scatter(:SepalLength, :SepalWidth, group=iris.Species)
"""

replay(instructions, use_ghostwriter=true, julia_project=@__DIR__)
