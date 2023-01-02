using Replay

instructions = [
    ";echo hello",
    CTRL_C,
    "println(\"Hello\")",
]

replay(instructions, use_ghostwriter=true)
