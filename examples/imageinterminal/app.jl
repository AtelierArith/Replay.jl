using Replay

instructions = """
using TestImages
using ImageInTerminal
testimage("mandril_color")
"""

replay(instructions, julia_project = @__DIR__)
