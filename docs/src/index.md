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
