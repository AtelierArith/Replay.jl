using Replay

instructions = raw"""
using OhMyREPL
using Printf
println("HelloWorld")
N = 10
@printf "%.2f %.2f %.2f\n" sin(pi/4) cos(pi/4) tan(pi/4)
@show N
"""

replay(instructions, use_ghostwriter=false, julia_project=@__DIR__)

replay(instructions, use_ghostwriter=true, julia_project=@__DIR__)
