using Replay

@assert !Base.get_have_color() "please run julia with --color=no e.g. `julia --color=no examples/disable_color/app.jl`"

instructions = [
    """
    function greet(msg::String="Hello!")
        println(msg)
    end
    """,
    "greet()",
    """greet("Hello, World!")""",
]

replay(instructions, use_ghostwriter = false, cmd="--color=no")
replay(instructions, use_ghostwriter = true, cmd="--color=no")
