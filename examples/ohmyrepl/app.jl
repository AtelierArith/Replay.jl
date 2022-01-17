using Replay

instructions = """
using OhMyREPL
println("HelloWorld")
N = 10
@show N
"""

replay(instructions, use_ghostwriter = false, julia_project = @__DIR__)
