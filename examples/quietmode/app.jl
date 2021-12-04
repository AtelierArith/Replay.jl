using Replay

instructions = """
println("julia -q")
"""

replay(instructions, cmd="-q")
