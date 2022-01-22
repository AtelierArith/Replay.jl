using Replay

instructions = raw"""
using OhMyREPL

using LinearAlgebra
using Printf
using Statistics

using DataFrames
using RDatasets
using StatsPlots

# use UnicodePlots.jl as backend
unicodeplots();

iris = dataset("datasets", "iris");
@show names(iris);
N = size(iris, 1)
@show names(iris);
# Execute PCA
X = Matrix(select(iris, Not(:Species)))
X .= X .- mean(X, dims=1)
Σ = (X' * X)/N # will be the covariance matrix for iris dataset
e = eigen(Σ, sortby = -);
# display  eigen values in descending order
e.values
# eigen vectors
e.vectors

@printf "1st contribution ratio = %.2f percent\n" 100e.values[1]/sum(e.values)
@printf "2nd contribution ratio = %.2f percent\n" 100e.values[2]/sum(e.values)

# Visualize the reduced data via PCA
topk = 2;
reduced_data = DataFrame(X * e.vectors[:, 1:topk], [:X, :Y]);
@df reduced_data scatter(:X, :Y, group=iris.Species)
"""

replay(instructions, use_ghostwriter = true, julia_project = @__DIR__)
