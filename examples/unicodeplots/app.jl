using Replay

instructions = """
using UnicodePlots
histogram(randn(1000) .* 0.1, nbins = 15, closed = :right, xscale=:log10)
heatmap(collect(0:30) * collect(0:30)', xfact=0.1, yfact=0.1, xoffset=-1.5, colormap=:inferno)
"""

replay(instructions, julia_project = @__DIR__)
