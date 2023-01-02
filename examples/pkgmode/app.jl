using Replay

instructions = [
    "# Pkg mode",
    "] st",
    CTRL_C,
]

replay(instructions, use_ghostwriter=true)
