using Replay

instructions = """
using TestImages
using Sixel
sixel_encode(testimage("mandril_color"))
"""

replay(instructions, julia_project=@__DIR__)
