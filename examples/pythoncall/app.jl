using Replay

repl_script = """
using PythonCall
jlv = [1,2,3]
pyv = Py(jlv)
pyv.append(4)
pyv
jlv
"""

replay(
    repl_script,
    stdout,
    julia_project=@__DIR__,
    use_ghostwriter=true,
    cmd="--color=yes",
)
