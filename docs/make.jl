using Replay
using Documenter

DocMeta.setdocmeta!(Replay, :DocTestSetup, :(using Replay); recursive=true)

# Building the package manual never installs example dependencies or records a REPL.
# Full examples and recordings live in the independently built ReplayGallery.jl.
makedocs(;
    modules=[Replay],
    authors="Satoshi Terasaki <terasakisatoshi.math@gmail.com> and contributors",
    repo="https://github.com/AtelierArith/Replay.jl/blob/{commit}{path}#{line}",
    sitename="Replay.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        edit_link="main",
        canonical="https://AtelierArith.github.io/Replay.jl",
        repolink="https://github.com/AtelierArith/Replay.jl",
    ),
    pages=["Getting started" => "index.md", "API" => "api.md"],
)
