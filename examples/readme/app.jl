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

replay(repl_script, stdout, julia_project=@__DIR__, use_ghostwriter=true, cmd="--color=yes")