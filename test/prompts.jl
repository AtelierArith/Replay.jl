@testset "interactive TerminalMenus" begin
    # ASCII menus use the same "> " delimiter as the normal REPL. Keep the
    # menu request and its keystrokes separate: the request awaits input.
    buf = replay(
        [
            "using REPL.TerminalMenus",
            "menu = RadioMenu([\"apple\", \"orange\", \"grape\"], pagesize=3);",
            "choice = request(\"Choose fruit:\", menu)",
            "$(DOWN_ARROW)$(DOWN_ARROW)\r",
            "@show choice",
            "cancelled = request(\"Cancel selection:\", menu)",
            "q",
            "@show cancelled",
            "again = request(\"Choose again:\", RadioMenu([\"yes\", \"no\"]))",
            "\r",
            "@show again",
        ],
        IOBuffer();
        cmd=`-q --color=no`,
    )
    plain = replace(String(take!(buf)), r"\e\[[0-?]*[ -/]*[@-~]" => "")
    @test occursin(r"(?m)^choice = 3\r?$", plain)
    @test occursin(r"(?m)^cancelled = -1\r?$", plain)
    @test occursin(r"(?m)^again = 1\r?$", plain)
end

@testset "numbered prompts" begin
    buf = replay(
        ["x = 1 + 1", "@show x"], IOBuffer();
        cmd=`-q --color=no -e 'using REPL; atreplinit(repl -> (repl.interface = REPL.setup_interface(repl); REPL.numbered_prompt!(repl)))'`,
        startup_prompt="In [1]: ",
        prompt_delimiter="]: ",
    )
    plain = replace(String(take!(buf)), r"\e\[[0-?]*[ -/]*[@-~]" => "")
    @test occursin("In [1]: ", plain)
    @test occursin("In [2]: ", plain)
    @test occursin(r"(?m)^x = 2\r?$", plain)
    @test_throws ArgumentError replay(String[]; startup_prompt="")
    @test_throws ArgumentError replay(String[]; prompt_delimiter="")
    @test_throws ArgumentError replay(
        String[];
        startup_prompt="In [1]: ",
        use_ghostwriter=true,
    )
end
