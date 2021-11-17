using Replay

instructions = """
using FileIO, Sixel, Plots
gr()
buf = IOBuffer()
show(buf, MIME("image/png"), plot(sin, size=(1000, 750)))
buf |> load |> sixel_encode
"""

replay(instructions)
