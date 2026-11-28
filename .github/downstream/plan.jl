# Reads changed repository paths, one per line, from stdin and writes the downstream tests
# they call for as GitHub Actions outputs: `recipes`, the recipe directories to build, and
# `tests`, one entry per recipe and package. A path selects a recipe when it is the recipe's
# directory or lies inside it. Also writes `julia_version`, the Julia that CI builds with.
using TOML

const ROOT = dirname(dirname(@__DIR__))

config = TOML.parsefile(joinpath(ROOT, ".github", "downstream_tests.toml"))
changed = filter(!isempty, strip.(readlines(stdin)))
selected(dir) = any(p -> p == dir || startswith(p, dir * "/"), changed)
dirs = sort!([dir for dir in keys(config) if selected(dir)])

# The values end up in a matrix, so allow only characters that need no JSON escaping.
function json_string(s)
    occursin(r"^[A-Za-z0-9_.@+/-]+$", s) || error("unexpected characters in $(repr(s))")
    return "\"$s\""
end
json_object(pairs...) = "{" * join(["$(json_string(k)):$(json_string(v))" for (k, v) in pairs], ",") * "}"

# Artifact names may not contain slashes.
key(dir) = replace(dir, "/" => "-")
recipes = [json_object("dir" => dir, "key" => key(dir)) for dir in dirs]
tests = [json_object("recipe" => dir, "key" => key(dir), "package" => package)
         for dir in dirs for package in config[dir]]

manifest = TOML.parsefile(joinpath(ROOT, "Manifest.toml"))

outputs = """
recipes=[$(join(recipes, ","))]
tests=[$(join(tests, ","))]
julia_version=$(manifest["julia_version"])
"""
print(outputs)
haskey(ENV, "GITHUB_OUTPUT") && open(io -> print(io, outputs), ENV["GITHUB_OUTPUT"], "a")
