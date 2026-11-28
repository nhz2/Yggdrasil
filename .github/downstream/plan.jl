# Reads the paths a pull request changes from stdin and writes, as GitHub Actions outputs, the
# recipes in `.github/downstream_tests.toml` they touch and the packages to test against them.
using TOML

config = TOML.parsefile(joinpath(@__DIR__, "..", "downstream_tests.toml"))
changed = filter(!isempty, readlines(stdin))
recipes = [dir for dir in keys(config) if any(p -> startswith(p, dir * "/"), changed)]
packages = unique(package for dir in recipes for package in config[dir])

json(strings) = "[" * join(["\"$s\"" for s in strings], ",") * "]"
outputs = """
recipes=$(json(recipes))
packages=$(json(packages))
"""
print(outputs)
haskey(ENV, "GITHUB_OUTPUT") && open(io -> print(io, outputs), ENV["GITHUB_OUTPUT"], "a")
