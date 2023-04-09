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
            dir_script = joinpath(dir_examples, name)
            path_script = joinpath(dir_script, "app.jl")
            url_script = "https://github.com/AtelierArith/Replay.jl/blob/$(COMMIT)/examples/$(name)/app.jl"
            path_record = joinpath(dir_script, "record.cast")
            script = "using Replay; include(\"$path_script\")"
            cmd_jl = `julia --project -e $(script)`
            cmd_jl_str = string(cmd_jl)[2:end-1]
            if name == "disable_color"
                cmd_jl = `julia --color=no --project -e $(script)`
            end
            cmd_record = `asciinema rec $(path_record) --command $(cmd_jl_str) --overwrite`
            cmd_upload = `asciinema upload $(path_record)`

            # Dry run not to record precompilation
            run(cmd_jl)

            # Record the REPL output with asciinema
            run(cmd_record)

            # Upload the record and get the ID
            c = IOCapture.capture() do
                run(cmd_upload)
            end
            id_begin = findfirst("https://asciinema.org/a/", c.output)[end] + 1
            id_end = findnext("\n", c.output, id_begin)[begin] - 1
            id_upload = c.output[id_begin:id_end]

            # Add an markdown subsection of the example
            script_md *= """

            ### $(example.title)
            Script in [`$(path_script)`]($(url_script)):
            ```julia
            $(read(path_script, String))
            ```
            How to replay the script in the REPL:
            ```
            $(cmd_jl_str)
            ```
            The above command replays the output like this:
            ```@raw html
            <script src="https://asciinema.org/a/$(id_upload).js" id="asciicast-$(id_upload)" async></script>
            ```
            """
            push!(names_example, name)
        end
    end
    write(path_md, script_md)
    for name in setdiff(readdir(dir_examples), names_example)
        @warn "$name is not generated"
    end
end

sections = [
    "Basics" => [
        (name="readme", title="Basic example in the README"),
        (name="helloworld", title="Hello world"),
    ],
    "More in REPL" => [
        (name="helpmode", title="Help mode"),
        (name="pkgmode", title="Package mode"),
        (name="shellmode", title="Shell mode"),
        (name="tab_completion", title="Tab completion"),
    ],
    "CLI options" => [
        (name="disable_color", title="Disable color"),
        (name="quietmode", title="Quiet mode"),
    ],
    "Working with other packages" => [
        (name="ohmyrepl", title="OhMyREPL.jl"),
        (name="unicodefun", title="UnicodeFun.jl"),
        (name="pythoncall", title="PythonCall.jl"),
        (name="unicodeplots", title="UnicodePlots.jl"),
        (name="unicodeplots_animated", title="UnicodePlots.jl (animated)"),
        (name="imageinterminal", title="ImageInTerminal.jl"),
        # Sixel output is not supported by asciinema
        # (name="sixel", title="Sixel.jl"),
        # (name="plots_with_sixel", title="Sixel.jl"),
        (name="iris", title="RDatasets.jl and more (Iris dataset)"),
    ],
    "Have fun!" => [
        (name="use_ghostwriter", title="Why We Created Julia (with `use_ghostwriter`)"),
    ],
]

generate_example_page(sections)

makedocs(;
    modules=[Replay],
    authors="Satoshi Terasaki <terasakisatoshi.math@gmail.com> and contributors",
    repo="https://github.com/AtelierArith/Replay.jl/blob/{commit}{path}#{line}",
    sitename="Replay.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://AtelierArith.github.io/Replay.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Examples" => "examples.md"
    ],
)

deploydocs(; repo="github.com/AtelierArith/Replay.jl", devbranch="main")
