module ThreadsXBenchmarks

import JSON
using ArgCheck: @argcheck
using BangBang
using InteractiveUtils: versioninfo
using Logging: current_logger
using ThreadsX

const setup_terminalloggers = """
let Logging =
        Base.require(Base.PkgId(Base.UUID(0x56ddb016857b54e1b83ddb4d58db5568), "Logging")),
    TerminalLoggers = Base.require(Base.PkgId(
        Base.UUID(0x5d786b921e484d6f91516b4477ca9bed),
        "TerminalLoggers",
    ))

    Logging.global_logger(TerminalLoggers.TerminalLogger())
end
"""

is_using_terminal_logger() =
    Base.PkgId(parentmodule(typeof(current_logger()))).uuid ==
    Base.UUID(0x5d786b921e484d6f91516b4477ca9bed)

function runscript(
    script::AbstractString,
    ARGS::AbstractVector{<:AbstractString};
    env = nothing,
)
    @argcheck isfile(script)
    code = """
    $(Base.load_path_setup_code())
    $(is_using_terminal_logger() ? setup_terminalloggers : "")
    let script = popfirst!(ARGS)
        @eval Base PROGRAM_FILE = \$script
        include(script)
    end
    """
    cmd = `$(Base.julia_cmd()) --startup-file=no`
    if Base.have_color
        cmd = `$cmd --color=yes`
    end
    cmd = `$cmd -e $code $script $ARGS`
    if env !== nothing
        fullenv = copy(ENV)
        for (k, v) in env
            fullenv[k] = convert(String, v)
        end
        cmd = setenv(cmd, fullenv)
    end
    run(cmd)
end

function physical_cores()
    lines = split(read(`lscpu --parse`, String), "\n", keepempty = false)
    rows = [map(strip, split(ln, ",")) for ln in lines if !startswith(ln, "#")]
    return length(Set(r[2] for r in rows))
end

function run_nthreads(
    outdir::AbstractString;
    nthreads_range::AbstractVector{<:Integer} = 1:physical_cores(),
)
    @info "Measuring scaling with respect to number of threads"

    mkpath(outdir)
    open(versioninfo, joinpath(outdir, "versioninfo.txt"), write = true)

    scriptdir = joinpath(@__DIR__, "scripts")

    @info "Running: `scaling_nthreads_baseline.jl`"
    runscript(
        joinpath(scriptdir, "scaling_nthreads_baseline.jl"),
        [joinpath(outdir, "scaling_nthreads_baseline")],
        env = ["JULIA_NUM_THREADS" => "1"],
    )

    for nthreads in nthreads_range
        outputstem = joinpath(outdir, "scaling_nthreads-$nthreads")
        @info "Running: `scaling_nthreads_target.jl` with $nthreads thread(s)"
        runscript(
            joinpath(scriptdir, "scaling_nthreads_target.jl"),
            [outputstem];
            env = ["JULIA_NUM_THREADS" => string(nthreads)],
        )
    end
    return
end

function run_datasize(outdir::AbstractString; nthreads::Integer = physical_cores())
    @info "Measuring scaling with respect to data size"

    mkpath(outdir)
    open(versioninfo, joinpath(outdir, "versioninfo.txt"), write = true)

    @info "Running: `scaling_datasize.jl`"
    scriptdir = joinpath(@__DIR__, "scripts")
    runscript(
        joinpath(scriptdir, "scaling_datasize.jl"),
        [joinpath(outdir, "scaling_datasize")],
        env = ["JULIA_NUM_THREADS" => string(nthreads)],
    )
    return
end

function run_all(
    outdir::AbstractString;
    nthreads_range::AbstractVector{<:Integer} = 1:physical_cores(),
    default_nthreads::Integer = maximum(nthreads_range),
)
    run_nthreads(outdir; nthreads_range = nthreads_range)
    run_datasize(outdir; nthreads = default_nthreads)
    return
end

include("loading.jl")

end # module
