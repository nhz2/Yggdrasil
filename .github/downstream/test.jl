# Runs the tests of the latest registered version of package ARGS[2] with the JLLs that
# build.jl staged in directory ARGS[1] in place of the registered ones.
#
# A JLL version that is breaking for what the package uses now, and that the package's
# compat does not admit yet, is skipped rather than failed: the package has to opt in to it.
using Pkg, TOML
using Artifacts: artifact_meta

staged, package = ARGS
products = joinpath(abspath(staged), "products")
jlls = filter(isdir, readdir(joinpath(abspath(staged), "dev"); join=true))
isempty(jlls) && error("no JLLs staged in $staged")

notice(msg) = println(get(ENV, "GITHUB_ACTIONS", "") == "true" ? "::notice::$msg" : msg)

# Point each JLL's artifacts at the tarballs that build.jl staged, so that Pkg installs
# them from there: their release URLs do not exist yet.
file_url(path) = "file://" * (Sys.iswindows() ? "/" : "") * replace(path, '\\' => '/')
new = Dict{String,VersionNumber}()
for jll in jlls
    project = TOML.parsefile(joinpath(jll, "Project.toml"))
    name = project["name"]
    new[name] = VersionNumber(project["version"])
    toml = joinpath(jll, "Artifacts.toml")
    artifacts = TOML.parsefile(toml)
    for (artifact, entries) in artifacts
        if artifact_meta(artifact, toml) === nothing
            notice("$name has no $artifact artifact for this platform; nothing to test")
            exit(0)
        end
        for entry in (entries isa AbstractVector ? entries : [entries]),
                download in get(entry, "download", [])
            file = joinpath(products, basename(download["url"]))
            isfile(file) && (download["url"] = file_url(file))
        end
    end
    open(io -> TOML.print(io, artifacts), toml, "w")
end

Pkg.activate(; temp=true)
# The latest release that this Julia and the registered JLLs allow, held there so that
# the resolver cannot fall back to an older one that admits the new JLLs.
Pkg.add(package)
Pkg.pin(package)
registered = Dict(dep.name => dep.version for dep in values(Pkg.dependencies()))
for name in keys(new)
    haskey(registered, name) || error("$package does not depend on $name")
end

# Whether going from version `old` to `new` breaks compatibility, as Pkg's caret specifiers
# count it.
function breaking(old, new)
    old.major != new.major && return true
    old.major == 0 && old.minor != new.minor && return true
    return old.major == 0 && old.minor == 0 && old.patch != new.patch
end

try
    Pkg.develop([PackageSpec(path=jll) for jll in jlls])
catch err
    err isa Pkg.Resolve.ResolverError || rethrow()
    bumps = [name for name in keys(new) if breaking(registered[name], new[name])]
    isempty(bumps) && rethrow()
    notice("$package $(registered[package]) does not admit " *
           join(["$name $(new[name]) (it uses $(registered[name]))" for name in bumps], ", ") *
           ": a breaking version that it has to opt in to, so its tests are skipped")
    exit(0)
end
Pkg.status()
Pkg.test(package)
