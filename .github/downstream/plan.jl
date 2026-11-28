# Reads the paths a pull request changes from stdin and writes, as GitHub Actions outputs, the
# recipes in `.github/downstream_tests.toml` they touch and the package tests those call for.
using TOML

config = TOML.parsefile(joinpath(@__DIR__, "..", "downstream_tests.toml"))
changed = filter(!isempty, readlines(stdin))
dirs = [dir for dir in keys(config) if any(p -> startswith(p, dir * "/"), changed)]

# Artifact names may not contain slashes.
key(dir) = replace(dir, "/" => "-")
recipes = ["{\"dir\":\"$dir\",\"key\":\"$(key(dir))\"}" for dir in dirs]
tests = ["{\"recipe\":\"$dir\",\"key\":\"$(key(dir))\",\"package\":\"$package\"}"
         for dir in dirs for package in config[dir]]

outputs = """
recipes=[$(join(recipes, ","))]
tests=[$(join(tests, ","))]
"""
print(outputs)
haskey(ENV, "GITHUB_OUTPUT") && open(io -> print(io, outputs), ENV["GITHUB_OUTPUT"], "a")
