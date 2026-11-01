# Run in a fresh process so the test harness cannot supply Pkg implicitly.
using Replay
using Test
using Pkg

canonical_pkg_prompt() = isdefined(Replay.REPL, :Pkg_promptf) ?
    Replay.REPL.Pkg_promptf() : Pkg.REPLMode.promptf()

@testset "project-qualified ghostwriter Pkg prompts" begin
    mktempdir() do dir
        named = joinpath(dir, "named")
        unnamed = joinpath(dir, "unnamed")
        mkpath(named)
        mkpath(unnamed)
        write(joinpath(named, "Project.toml"), "name = \"PromptRegression\"\n")
        write(joinpath(unnamed, "Project.toml"), "[deps]\n")
        original = Base.active_project()
        try
            for (project, name) in ((named, "PromptRegression"), (unnamed, "unnamed"))
                Pkg.activate(project; io=devnull)
                expected = canonical_pkg_prompt()
                @test occursin("($name)", expected)
                @test Replay.ghost_mode(:repl).prompt == expected
                mode, script, next_mode = Replay._next_mode("]status", :julian)
                @test mode.prompt == expected
                @test script == "status"
                @test next_mode == :repl

                if !isdefined(Replay.REPL, :Pkg_promptf)
                    # Stock Julia 1.10 includes Pkg in its sysimage. Simulate
                    # the missing registry entry that triggered the old bare
                    # prompt fallback, without changing the parent test process.
                    pkg_id = Base.PkgId(Pkg)
                    pkg = pop!(Base.loaded_modules, pkg_id)
                    actual = try
                        Replay.ghost_mode(:repl).prompt
                    finally
                        Base.loaded_modules[pkg_id] = pkg
                    end
                    @test actual == expected
                end
            end
        finally
            Pkg.activate(original; io=devnull)
        end
    end
end
