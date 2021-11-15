# Replay [![Build Status](https://github.com/AtelierArith/Replay.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/AtelierArith/Replay.jl/actions/workflows/CI.yml?query=branch%3Amain) [![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://AtelierArith.github.io/Replay.jl/dev)

# Why?

Let's assume you have to record(e.g. take a screenshot) demo that types 9 lines like below:

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
$ cat app.jl
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

replay(repl_script, stdout, color = :yes)
$ julia app.jl
```

![demo](https://user-images.githubusercontent.com/16760547/141813986-d662f944-3377-40ca-872e-b2796dbc3102.gif)


You can redirect the output into a file

```julia
$ julia app.jl > output.txt
$ cat output.txt
```

![redirect_output](https://user-images.githubusercontent.com/16760547/141814010-ac335f23-1348-4cba-8f17-6fdf4621efe9.gif)

# Acknowledgements

Replay.jl is based on 

- [FakePTYs.jl](https://github.com/JuliaLang/julia/blob/v1.6.3/test/testhelpers/FakePTYs.jl)
- [generate_precompile.jl](https://github.com/JuliaLang/julia/blob/v1.6.3/contrib/generate_precompile.jl)