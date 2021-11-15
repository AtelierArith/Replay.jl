using Replay
using Documenter

DocMeta.setdocmeta!(Replay, :DocTestSetup, :(using Replay); recursive=true)

makedocs(;
    modules=[Replay],
    authors="Satoshi Terasaki <terasakisatoshi.math@gmail.com> and contributors",
    repo="https://github.com/terasakisatoshi/Replay.jl/blob/{commit}{path}#{line}",
    sitename="Replay.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://terasakisatoshi.github.io/Replay.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/terasakisatoshi/Replay.jl",
    devbranch="main",
)
