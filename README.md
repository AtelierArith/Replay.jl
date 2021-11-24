# Replay

[![CI](https://github.com/AtelierArith/Replay.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/AtelierArith/Replay.jl/actions/workflows/CI.yml) [![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://AtelierArith.github.io/Replay.jl/dev)

Replay your REPL instructions [something like this](https://github.com/AtelierArith/Replay.jl/issues/1#issuecomment-970441437).

# Why?
![](docs/src/assets/logo-dark.svg)

# Introduction

Let’s assume you have to record your screen to explain something about Julia topics e.g. how to use REPL, how to use your great package on Julia REPL etc… You are supposed to input your source code by hand line by line. Imagine that you type the following lines.

```
julia> 2+2
julia> print("")
julia> display([1])
julia> display([1 2; 3 4])
julia> @time 1+1
julia> using Pkg; Pkg.activate(".")
pkg> add Example
pkg> rm Example
pkg> st
```

Should we type them one by one using your fingers? We are too lazy to do.
Don't worry! Our package `Replay.jl` saves your life!

# Usage

```console
$ cd path/to/this/repository
$ cat ./examples/readme/app.jl
using Replay

repl_script = """
2+2
print("")
display([1])
display([1 2; 3 4])
@time 1+1
using Pkg; Pkg.activate(".")
] add Example
rm Example
st
$CTRL_C
"""

replay(repl_script, stdout, color = :yes, julia_project=@__DIR__, use_ghostwriter=true)
$ julia --project=@. -e 'using Pkg; Pkg.instantiate()'
$ julia --project=@. ./examples/readme/app.jl
```

![demo](https://user-images.githubusercontent.com/16760547/142026114-15029088-4f3e-4404-beba-e544f3a5a667.gif)


You can redirect the output of the program into a file:

```julia
$ julia --project=@. ./examples/readme/app.jl > output.txt
$ cat output.txt
```

Tips: you can set `replay(instructions; color=:no)` as necessary.

## Examples

- We provide several examples to testout our Package.

```console
$ tree examples
examples
├── imageinterminal
│   ├── Project.toml
│   └── app.jl
├── plots_with_sixel
│   ├── Project.toml
│   └── app.jl
├── readme
│   ├── Project.toml
│   └── app.jl
├── sixel
│   ├── Project.toml
│   └── app.jl
├── unicodeplots
│   ├── Project.toml
│   └── app.jl
└── use_ghostwriter
    └── app.jl
```

# Acknowledgements

Replay.jl is based on 

- [FakePTYs.jl](https://github.com/JuliaLang/julia/blob/v1.6.3/test/testhelpers/FakePTYs.jl)

The idea of how to replay julia session comes from

- [generate_precompile.jl](https://github.com/JuliaLang/julia/blob/v1.6.3/contrib/generate_precompile.jl)

@hyrodium san provided an excellent logo for our package.
- See [this PR #7](https://github.com/AtelierArith/Replay.jl/pull/7).

![](docs/src/assets/logo.svg)

