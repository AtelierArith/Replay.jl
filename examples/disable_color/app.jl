using Replay

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
