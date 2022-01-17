using Replay

instructions = [
    "using UnicodeFun",
    "\"\\\\pi\" |> to_latex"
]

replay(instructions, julia_project = @__DIR__)
