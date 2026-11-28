# Runs the tests of the latest registered version of package ARGS[2] with the JLLs that
# build.jl staged in directory ARGS[1].
using Pkg

staged, package = ARGS
for tarball in filter(!endswith(".json"), readdir(joinpath(staged, "products"); join=true))
    Pkg.Artifacts.create_artifact(dir -> Pkg.PlatformEngines.unpack(tarball, dir))
end

Pkg.activate(; temp=true)
Pkg.add(package)
Pkg.pin(package)
Pkg.develop([PackageSpec(path=jll) for jll in readdir(joinpath(staged, "dev"); join=true)])
Pkg.test(package)
