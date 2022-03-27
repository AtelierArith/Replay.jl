# [Replay](https://github.com/AtelierArith/Replay.jl)

[![CI](https://github.com/AtelierArith/Replay.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/AtelierArith/Replay.jl/actions/workflows/CI.yml) [![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://AtelierArith.github.io/Replay.jl/dev)

Replay your REPL instructions something like this:

[![asciicast](https://asciinema.org/a/V3w9CQXAesZUgAeTIUXytkpws.svg)](https://asciinema.org/a/V3w9CQXAesZUgAeTIUXytkpws)

![](docs/src/assets/logo-dark.svg)

# Introduction

Let’s assume you have to record your screen to explain something about Julia topics e.g. how to use REPL, how to use your great package in Julia REPL etc… You are supposed to input your source code by hand line by line. Imagine that you type the following lines.

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
$ git clone https://github.com/AtelierArith/Replay.jl.git
$ cd Replay.jl
$ cat ./examples/readme/app.jl
using Replay

repl_script = """
2+2
print("")
display([1])
display([1 2; 3 4])
@time 1+1
using Pkg; Pkg.activate(".")
]add Example
rm Example
st
$CTRL_C
"""

replay(repl_script, stdout, julia_project=@__DIR__, use_ghostwriter=true, cmd="--color=yes")
$ julia --project=@. -e 'using Pkg; Pkg.instantiate()'
$ julia --project=@. ./examples/readme/app.jl
$ # Below is optional
$ asciinema rec result.cast --command "julia --project=@. ./examples/readme/app.jl"
$ asciinema play result.cast
```

[![asciicast](https://asciinema.org/a/WeyJwfjliWRSzliWMnbBQNtJP.svg)](https://asciinema.org/a/WeyJwfjliWRSzliWMnbBQNtJP)


You can redirect the output of the program into a file:

```julia
$ julia --project=@. ./examples/helloworld/app.jl > output.txt
$ cat output.txt
```

Tips: you can set `replay(instructions; cmd="--color=no")` as necessary.

```julia
$ julia examples/disable_color/app.jl > output.txt
$ cat output.txt
```

## Record instructions using [asciinema](https://asciinema.org/)

- [asciinema](https://asciinema.org/) is a free and open source solution for recording terminal sessions and sharing them on the web. It can be used in combination with Replay.jl with the following commands:

```console
$ pip3 install asciinema # install `asciinema`
$ asciinema rec output.cast --command "julia examples/helloworld/app.jl"
$ asciinema play output.cast
```

See [This issue](https://github.com/AtelierArith/Replay.jl/issues/23) to learn more.

## Examples

- We provide several examples to testout our Package.

```console
$ tree examples
examples
├── disable_color
│   └── app.jl
├── helloworld
│   └── app.jl
├── imageinterminal
│   ├── Project.toml
│   └── app.jl
├── iris
│   ├── Project.toml
│   └── app.jl
├── ohmyrepl
│   ├── Project.toml
│   └── app.jl
├── plots_with_sixel
│   ├── Project.toml
│   └── app.jl
├── quietmode
│   └── app.jl
├── readme
│   ├── Project.toml
│   └── app.jl
├── sixel
│   ├── Project.toml
│   └── app.jl
├── unicodefun
│   ├── Project.toml
│   └── app.jl
├── unicodeplots
│   ├── Project.toml
│   └── app.jl
├── unicodeplots_animated
│   ├── Project.toml
│   └── app.jl
└── use_ghostwriter
    └── app.jl

```

# Breaking Change

- The internal logic of the program has been changed to stabilize its operation. As a side effect, we had to make some destructive changes to the API.
- Note that `color` kwarg of `replay` is removed since `v0.4.x` . Use `cmd="--color=yes"` or `cmd="--color=no"` instead.

# Restriction

- Replay.jl does not work on Windows. Please use WSL2 instead.

# Acknowledgements

Replay.jl is based on

- [FakePTYs.jl](https://github.com/JuliaLang/julia/blob/v1.6.3/test/testhelpers/FakePTYs.jl)

The idea of how to replay julia session comes from

- [generate_precompile.jl](https://github.com/JuliaLang/julia/blob/v1.6.3/contrib/generate_precompile.jl)

[@hyrodium](https://github.com/hyrodium) san provided an excellent logo for our package.
- See [this PR #7](https://github.com/AtelierArith/Replay.jl/pull/7).

![](docs/src/assets/logo.svg)

# Appendix

## Blog post

- [Julia Discourse](https://discourse.julialang.org/t/ann-replay-jl-replay-instructions/71655)
- [Zenn.dev (Japanese blog post)](https://zenn.dev/terasakisatoshi/articles/b32638b8f6a34a)

## YouTube
- [Why We Created (Replay.jl for) Julia](https://www.youtube.com/watch?v=HNOK1sK-F3I)
- [Making Replay.jl](https://www.youtube.com/watch?v=KlXNVgv6b24)
