# Builds the recipe in directory ARGS[1] for the platforms that downstream.yml tests on, and
# stages the JLLs it generates (`dev/<name>_jll`) and their tarballs (`products/`) in
# directory ARGS[2].
# Run it in the repository's root project, which BinaryBuilder runs in.
using JSON
using Base.BinaryPlatforms

recipe, staged = abspath.(ARGS)

# The (arch, os, libc) of each platform in downstream.yml's test matrix; keep them in sync.
const TESTED = Set([
    ("x86_64", "linux", "glibc"),
    ("i686", "linux", "glibc"),
    ("aarch64", "linux", "glibc"),
    ("x86_64", "macos", nothing),
    ("aarch64", "macos", nothing),
    ("x86_64", "windows", nothing),
    ("i686", "windows", nothing),
])

julia = `$(Base.julia_cmd()) --project=$(Base.active_project())`
mkpath(staged)
cd(recipe) do
    meta = joinpath(staged, "meta.json")
    run(`$julia build_tarballs.jl --meta-json=$meta`)
    names = Set{String}()
    triplets = String[]
    for line in eachline(meta)
        build = JSON.parse(line)
        push!(names, build["name"])
        for triplet in build["platforms"]
            p = parse(Platform, triplet)
            (arch(p), os(p), libc(p)) in TESTED && push!(triplets, triplet)
        end
    end
    isempty(triplets) && error("$recipe builds none of the platforms downstream.yml tests on")

    run(`$julia build_tarballs.jl --verbose --deploy=local $(join(triplets, ","))`)

    # BinaryBuilder fixes the directory it deploys JLLs to when it is precompiled, so ask it.
    mkpath(joinpath(staged, "dev"))
    for name in names
        jll = readchomp(`$julia -e 'using BinaryBuilder; print(BinaryBuilder.codedir(ARGS[1]))' $name`)
        cp(jll, joinpath(staged, "dev", basename(jll)); force=true)
    end
    mkpath(joinpath(staged, "products"))
    for file in readdir("products")
        if endswith(file, ".tar.gz") && !occursin("-logs.", file)
            cp(joinpath("products", file), joinpath(staged, "products", file))
        end
    end
end
