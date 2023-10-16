using Replay
using Documenter
using IOCapture

DocMeta.setdocmeta!(Replay, :DocTestSetup, :(using Replay); recursive=true)

COMMIT::String = read(`git rev-parse HEAD`, String)[begin:end-1]

function generate_example_page(sections)
    path_md = joinpath(@__DIR__, "src", "examples.md")
    script_md = """
    # Examples
    """
    names_example = String[]
    dir_examples = joinpath(pkgdir(Replay), "examples")
    for section in sections
        name_section = section.first

        # Add an markdown section
        script_md *= """

        ## $(name_section)
        """
        examples = section.second
        for example in examples
            name = example.name
            title = example.title
            mode = example.mode
            dir_script = joinpath(dir_examples, name)
            path_script = joinpath(dir_script, "app.jl")
            url_script = "https://github.com/AtelierArith/Replay.jl/blob/$(COMMIT)/examples/$(name)/app.jl"
            script_jl = "using Replay; include(\"$path_script\")"
            cmd_jl = `julia --project=. $(example.options) -e $(script_jl)`
            cmd_jl_str = string(cmd_jl)[begin+1:end-1]

            # Add an markdown subsection of the example
            script_md *= """

            ### $(title)
            Script in [`$(path_script)`]($(url_script)):
            ```julia
            $(read(path_script, String))
            ```
            Replay the script in the REPL:
            ```
            $(cmd_jl_str)
            ```
            """

            if mode == :asciinema
                path_cast = joinpath(@__DIR__, "src", "assets", "$(name).cast")
                cmd_record = `asciinema rec $(path_cast) --command $(cmd_jl_str) --overwrite --title $("Replay.jl - "*title)`

                # Dry run not to record precompilation
                run(cmd_jl)
                # Record the REPL output with asciinema
                run(cmd_record)

                # Add the output of the example
                script_md *= """
                The output will be like this:
                ```@raw html
                <div id="$(name)"></div>
                <script>
                    AsciinemaPlayer.create('../assets/$(name).cast', document.getElementById('$(name)'), {
                        cols: 80,
                        rows: 24
                    });
                </script>
                ```
                """
            elseif mode == :disabled
                # Add the output of the example
                script_md *= """
                Currently, we don't have output for this example because asciinema does not supprot [SIXEL](https://github.com/saitoha/libsixel/).
                Please try it on your envionment!
                """
            end
            push!(names_example, name)
        end
    end

    # Save docs/src/examples.md
    write(path_md, script_md)

    # Warning for missing examples
    for name in setdiff(readdir(dir_examples), names_example)
        @warn "$name is not generated"
    end
end

sections = [
    "Basics" => [
        (
            name="readme",
            title="Basic example in the README",
            options=``,
            mode=:asciinema,
        ),
        (
            name="helloworld",
            title="Hello world",
            options=``,
            mode=:asciinema,
        ),
    ],
    "More in REPL" => [
        (
            name="helpmode",
            title="Help mode",
            options=``,
            mode=:asciinema,
        ),
        (
            name="pkgmode",
            title="Package mode",
            options=``,
            mode=:asciinema,
        ),
        (
            name="shellmode",
            title="Shell mode",
            options=``,
            mode=:asciinema,
        ),
        (
            name="tab_completion",
            title="Tab completion",
            options=``,
            mode=:asciinema,
        ),
    ],
    "CLI options" => [
        (
            name="disable_color",
            title="Disable color",
            options=`--color=no`,
            mode=:asciinema,
        ),
        (
            name="quietmode",
            title="Quiet mode",
            options=``,
            mode=:asciinema,
        ),
    ],
    "Working with other packages" => [
        (
            name="ohmyrepl",
            title="OhMyREPL.jl",
            options=``,
            mode=:asciinema,
        ),
        (
            name="unicodefun",
            title="UnicodeFun.jl",
            options=``,
            mode=:asciinema,
        ),
        (
            name="pythoncall",
            title="PythonCall.jl",
            options=``,
            mode=:asciinema,
        ),
        (
            name="unicodeplots",
            title="UnicodePlots.jl",
            options=``,
            mode=:asciinema,
        ),
        (
            name="unicodeplots_animated",
            title="UnicodePlots.jl (animated)",
            options=``,
            mode=:asciinema,
        ),
        (
            name="imageinterminal",
            title="ImageInTerminal.jl",
            options=``,
            mode=:asciinema,
        ),
        (
            name="sixel",
            title="Sixel.jl",
            options=``,
            mode=:disabled,
        ),
        (
            name="plots_with_sixel",
            title="Plots with Sixel.jl",
            options=``,
            mode=:disabled,
        ),
        (
            name="iris",
            title="RDatasets.jl and more (Iris dataset)",
            options=``,
            mode=:asciinema,
        ),
    ],
    "Have fun!" => [
        (
            name="use_ghostwriter",
            title="Why We Created Julia (with `use_ghostwriter`)",
            options=``,
            mode=:asciinema,
        ),
    ],
]

generate_example_page(sections)

makedocs(;
    modules=[Replay],
    authors="Satoshi Terasaki <terasakisatoshi.math@gmail.com> and contributors",
    repo="https://github.com/AtelierArith/Replay.jl/blob/{commit}{path}#{line}",
    sitename="Replay.jl",
    format=Documenter.HTML(;
        prettyurls=true,
        canonical="https://AtelierArith.github.io/Replay.jl",
        # The following assets are downloaded from https://github.com/asciinema/asciinema-player/releases/tag/v3.3.0.
        assets=String["assets/asciinema-player.css", "assets/asciinema-player.min.js"],
        repolink="https://github.com/AtelierArith/Replay.jl",
    ),
    pages=[
        "Home" => "index.md",
        "Examples" => "examples.md",
        "API" => "api.md",
    ],
)

deploydocs(; repo="github.com/AtelierArith/Replay.jl", devbranch="main")
