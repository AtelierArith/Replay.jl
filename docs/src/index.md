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

## Turning a script into instructions

`replay` accepts a vector of strings, where each string is one cell submitted to the
REPL. Passing a script as a single string works too: `replay(script)` splits it with
the REPL's own completeness rule, so multi-line definitions stay in one cell, and an
incomplete script raises an `ArgumentError` before the child REPL starts.

If you need the cells explicitly (to inspect or edit them before replaying), you can
derive them from the source with `Meta.parse`. Cutting the original source text rather
than re-printing the parsed expression keeps comments, formatting and trailing
semicolons intact.

```julia
function instructions(src::AbstractString)
    cells = String[]
    pos = firstindex(src)
    stop = lastindex(src)
    while pos <= stop
        expr, nextpos = Meta.parse(src, pos; raise=true)
        if expr !== nothing
            push!(cells, strip(src[pos:prevind(src, nextpos)]))
        end
        pos = nextpos
    end
    return cells
end

src = """
msg = "Hello World"
function greet(msg::String="Hello!")
    println(msg)
end
greet()
greet(; msg)
"""

replay(instructions(src); cmd=`-q --color=no`)
```

`instructions(src)` returns four cells; the multi-line function definition stays a
single cell.

`CodeEvaluation.parseblock` from
[CodeEvaluation.jl](https://github.com/JuliaDocs/CodeEvaluation.jl) implements the same
split and returns each expression together with its source text:

```julia
import CodeEvaluation

cells = [String(pe.code) for pe in CodeEvaluation.parseblock(src)]
```

It is not exported and may change, so the small helper above is preferable if you do not
already depend on that package. Do not use `@deparse` or `string(expr)` to build cells:
they discard comments, the original layout and trailing semicolons.

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
