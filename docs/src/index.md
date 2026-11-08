```@meta
CurrentModule = Replay
```

# Replay.jl

Replay Julia REPL instructions automatically, including help, package and shell modes.
The test suite supports the latest stable Julia (`1`) and the current long-term
support release (`lts`) on Linux, macOS and Windows. Julia 1.6 is no longer supported.

## Minimal example

Install Replay with `import Pkg; Pkg.add("Replay")`, then save this as `demo.jl`:

```julia
using Replay

replay(["x = 1 + 1", "println(\"Hello from Replay!\")", "@show x"];
       cmd=`-q --color=no`)
```

Run it with `julia --project demo.jl`. Replay launches a child Julia REPL;
it does not evaluate the instructions in your current session.
For package-specific demos, pass `julia_project` explicitly to [`replay`](@ref).

To capture text instead of displaying it:

```julia
output = replay("1 + 1", IOBuffer(); cmd=`-q --color=no`)
text = String(take!(output))
```

See the [API reference](@ref API) for options, control keys and `@deparse`.

## Replaying a script

Pass a script as a single string to replay it as a whole:

```julia
src = read("demo.jl", String)
replay(src; cmd=`-q --color=no`)
```

`replay` splits the script the same way the REPL decides that an input is
complete: it keeps reading lines while `Base.parse_input_line` reports an
`Expr(:incomplete)`, so a multi-line definition stays one input. A line starting
with `;`, `]` or `?` at column 0 switches to shell, pkg or help mode, and an
incomplete script raises an `ArgumentError` before the child REPL starts.
The vector form is still available when you want to control each submitted input
explicitly: `replay(["x = 1", "@show x"])`.

## Recording

Replay produces terminal output, not an MP4 file. An external terminal recorder
can capture the minimal example without screen recording:

```console
asciinema rec demo.cast --command "julia --project demo.jl"
asciinema play demo.cast
```

The full gallery, integration examples and recording/export instructions are
maintained separately in [ReplayGallery.jl](https://github.com/AtelierArith/ReplayGallery.jl).
This manual does not execute or download those examples during its build.
