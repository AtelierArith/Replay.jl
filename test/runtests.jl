using Replay
using Test

# Terminal escape sequences vary between Julia versions and platforms, so the
# tests assert on the plain text the REPL produces once cursor movement and
# color codes are removed. This keeps them version-independent without
# storing per-version reference transcripts.
const ANSI_ESCAPE = r"\e\[[0-?]*[ -/]*[@-~]"
const SGR_ESCAPE = r"\e\[[0-9;]*m"

plain_output(output::AbstractString) = replace(output, ANSI_ESCAPE => "")

function capture_replay(
    instructions;
    color::AbstractString="no",
    kwargs...,
)
    buf = IOBuffer()
    replay(
        instructions,
        buf;
        cmd=`-q --color=$color`,
        julia_project=dirname(Base.active_project()),
        kwargs...,
    )
    return String(take!(buf))
end

# Each scenario runs in a fresh child REPL and checks observable behaviour
# instead of a complete transcript.
const REPLAY_SCENARIOS = [
    (
        name="julian mode: results, macros and stdout",
        instructions=["x = 1 + 1", "@show x", "println(\"stdout-ok\")"],
        expected=[r"(?m)^2\r?$", r"(?m)^x = 2\r?$", r"(?m)^stdout-ok\r?$"],
        kwargs=(;),
    ),
    (
        name="julian mode: multiline definition",
        instructions=["function double(x)\n    2x\nend\n", "double(3)"],
        expected=[r"double \(generic function with 1 method\)", r"(?m)^6\r?$"],
        kwargs=(;),
    ),
    (
        name="julian mode: errors do not stop the session",
        instructions=["sqrt(-1)", "1 + 1"],
        expected=["DomainError", r"(?m)^2\r?$"],
        kwargs=(;),
    ),
    (
        name="help mode returns to julian mode",
        instructions=["?println", "1 + 1"],
        expected=["help?> ", "println", r"(?m)^2\r?$"],
        kwargs=(;),
    ),
    (
        name="shell mode",
        instructions=[";echo shell-ok"],
        expected=["shell> ", r"(?m)^shell-ok\r?$"],
        kwargs=(;),
    ),
    (
        name="pkg mode",
        instructions=["]status"],
        expected=[r"pkg> ", "Status `"],
        kwargs=(;),
    ),
    (
        name="ghostwriter types the instructions",
        instructions=["1 + 1"],
        expected=[r"(?m)^2\r?$"],
        kwargs=(; use_ghostwriter=true),
    ),
]

@testset "replay scenarios" begin
    for scenario in REPLAY_SCENARIOS
        @testset "$(scenario.name)" begin
            output = capture_replay(scenario.instructions; scenario.kwargs...)
            plain = plain_output(output)
            for pattern in scenario.expected
                @test occursin(pattern, plain)
            end
        end
    end
end

@testset "single string script" begin
    plain = plain_output(capture_replay("x = 1 + 1\n@show x"))
    @test occursin(r"(?m)^x = 2\r?$", plain)
end

@testset "script splitting follows the REPL's completeness rule" begin
    split_instructions = Replay._split_instructions
    @test split_instructions("x = 1\ny = 2\n") == ["x = 1", "y = 2"]
    @test split_instructions("function double(x)\n    2x\nend\ndouble(3)\n") ==
          ["function double(x)\n    2x\nend", "double(3)"]
    # Comments stay attached to the statement that follows them.
    @test split_instructions("# setup\nx = 1\n") == ["# setup\nx = 1"]
    # A complete block comment is not an incomplete input, and a following mode
    # command is still recognized.
    @test split_instructions("#= setup\ncomment =#\nx = 1\n") ==
          ["#= setup\ncomment =#\nx = 1"]
    @test split_instructions("#= setup\ncomment =#\n;echo shell-ok\n") ==
          ["#= setup\ncomment =#", ";echo shell-ok"]
    # Trailing comments are kept as a final no-op input.
    @test split_instructions("x = 1\n# trailing\n") == ["x = 1", "# trailing"]
    @test split_instructions("# only a comment\n") == ["# only a comment"]
    # A mode prefix at column 0 becomes its own input.
    @test split_instructions(";echo shell-ok\n1 + 1\n") == [";echo shell-ok", "1 + 1"]
    # Shell and pkg modes persist, so their commands are not parsed as Julia.
    @test split_instructions(";echo first\necho #= shell comment\n") ==
          [";echo first", "echo #= shell comment"]
    @test split_instructions(";echo first\nfunction f()\n") ==
          [";echo first", "function f()"]
    @test split_instructions("]status\nst\n\x03\nx = 1\n") ==
          ["]status", "st", "\x03", "x = 1"]
    # Keystroke cells keep their carriage returns and are not buffered into the
    # next Julia statement.
    @test split_instructions("\e[B\r\n") == ["\e[B\r"]
    @test split_instructions("x = 1\n\e[B\r\n") == ["x = 1", "\e[B\r"]
    @test split_instructions("\r\n") == ["\r"]
    # Blank input produces no cells.
    @test isempty(split_instructions("  \n\n"))
    # Incomplete input is rejected instead of leaving the child REPL waiting.
    @test_throws ArgumentError split_instructions("function f()\n    1\n")
    @test_throws ArgumentError replay(["function f()"], IOBuffer())
end

@testset "single string script with multiline definition" begin
    src = """
    function double(x)
        2x
    end
    double(3)
    """
    plain = plain_output(capture_replay(src))
    @test occursin(r"double \(generic function with 1 method\)", plain)
    @test occursin(r"(?m)^6\r?$", plain)
end

@testset "single string script with REPL modes" begin
    plain = plain_output(capture_replay(";echo shell-ok\n\x03\n1 + 1\n"))
    @test occursin("shell> ", plain)
    @test occursin(r"(?m)^2\r?$", plain)
end

@testset "single string script with interactive menu" begin
    src = """
    using REPL.TerminalMenus
    menu = RadioMenu([\"apple\", \"orange\"]);
    choice = request(\"Choose fruit:\", menu)
    $(DOWN_ARROW)\r
    @show choice
    """
    plain = plain_output(capture_replay(src))
    @test occursin(r"(?m)^choice = 2\r?$", plain)
end

@testset "multiline cell without trailing newline" begin
    # `@deparse` returns `string(expr)` without a trailing newline. Replay must
    # still submit the multiline cell to the REPL.
    instruction = @deparse function double(x)
        2x
    end
    @test !endswith(instruction, "\n")
    plain = plain_output(capture_replay([instruction, "double(3)"]))
    @test occursin(r"double \(generic function with 1 method\)", plain)
    @test occursin(r"(?m)^6\r?$", plain)
end

@testset "color output" begin
    instructions = ["1 + 1"]
    colored = capture_replay(instructions; color="yes")
    plain = capture_replay(instructions; color="no")
    @test occursin(SGR_ESCAPE, colored)
    @test !occursin(SGR_ESCAPE, plain)
end

@testset "Ctrl-C returns from pkg and shell mode" begin
    plain = plain_output(
        capture_replay(
            [";echo shell-ok", CTRL_C, "1 + 1", "]status", CTRL_C, "2 + 2"],
        ),
    )
    @test occursin("shell> ", plain)
    @test occursin(r"(?m)^2\r?$", plain)
    @test occursin(r"pkg> ", plain)
    @test occursin(r"(?m)^4\r?$", plain)
end

include("inst.jl")

if Sys.iswindows()
    @testset "Windows retains LineEdit tab completion" begin
        buf = replay(
            ["\\alpha$(TAB) = 7", "?nothing", "@show α"],
            IOBuffer();
            cmd=`-q --color=no`,
        )
        plain = plain_output(String(take!(buf)))
        @test occursin(r"(?m)^α = 7\r?$", plain)
    end
end

include("prompts.jl")
