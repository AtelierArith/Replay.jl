using Replay

instructions = raw"""
using UnicodeFun
using LaTeXStrings
str = L"\alpha + \beta + A\hat";
replace(str, "\$" => "") |> to_latex
"""

replay(instructions, julia_project="@.", use_ghostwriter=true)
