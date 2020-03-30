import JSON
using ArgCheck: @argcheck
using BangBang
using BenchmarkTools: @benchmarkable, BenchmarkTools
using ProgressLogging: @progress, @withprogress
using Random: MersenneTwister
using Referenceables: referenceable
using ThreadsX

ntproduct(; kwargs...) =
    Base.Generator(NamedTuple{keys(kwargs)}, Iterators.product(values(kwargs)...))

@inline function setavg!(a, b, c)
    a[] = (b + c) / 2
end

const BENCHMARKS = Dict{Symbol,NamedTuple{(:prepare, :run, :paramasdata, :paramaxes)}}(
    :sort => (
        prepare = (p, rng) -> rand(rng, p.dist.value, p.datasize),
        run =
            (p, r) -> ThreadsX.sort!(
                r;
                alg = p.alg.value,
                basesize = p.basesize,
                smallsize = p.smallsize,
            ),
        paramasdata =
            p -> (
                datasize = p.datasize,
                distribution = p.dist.label,
                alg = p.alg.label,
                basesize = p.basesize,
                smallsize = p.smallsize,
            ),
        paramaxes = (
            datasize = [1_000_000],
            dist = [
                (label = "wide", value = Float64),
                (label = "narrow", value = 0:0.01:1),
            ],
            alg = [
                (label = "ThreadsX.MergeSort", value = ThreadsX.MergeSort),
                (label = "ThreadsX.QuickSort", value = ThreadsX.QuickSort),
            ],
            basesize = [nothing],
            # basesize = [nothing, 20_000, 10_000, 5_000],
            smallsize = [nothing],
        ),
    ),
    :foreach_symmetrize => (
        prepare = function (p, rng)
            B = randn(rng, (p.datasize, p.datasize))
            A = similar(B)
            return (A = A, B = B)
        end,
        run = (p, r) -> ThreadsX.foreach(setavg!, referenceable(r.A), r.B, r.B'),
        paramasdata = identity,
        paramaxes = (datasize = [6000],),
    ),
    :sum_sin => (
        prepare = (p, rng) -> 1:p.datasize,
        run = (p, r) -> ThreadsX.sum(sin, r),
        paramasdata = identity,
        paramaxes = (datasize = [10_000_000],),
    ),
    :findfirst => (
        prepare = function (p, rng)
            xs = rand(rng, p.datasize)
            xs[2*end÷3] = -1
            xs
        end,
        run = (p, r) -> ThreadsX.findfirst(==(-1), r),
        paramasdata = identity,
        paramaxes = (datasize = [2^26],),
    ),
    :unique => (
        prepare = (p, rng) -> rand(rng, 1:10, p.datasize),
        run = (p, r) -> ThreadsX.unique(r),
        paramasdata = identity,
        paramaxes = (datasize = [10_000_000],),
    ),
)

# Workaround custom JSON lowering
asdict(x) = x
asdict(x::BenchmarkTools.Trial) = _asdict(x)
asdict(x::BenchmarkTools.Parameters) = _asdict(x)
_asdict(x) = Dict(n => asdict(getfield(x, n)) for n in fieldnames(typeof(x)))

function main(
    ARGS = ARGS;
    benchmark_definitions = BENCHMARKS,
    scriptname::AbstractString = basename(@__FILE__),
    tags::AbstractVector{<:AbstractString} = ["nthreads"],
)
    @argcheck length(ARGS) == 1
    outputstem, = ARGS

    benchmarks = []
    @progress "Benchmark" for (benchname, bench) in benchmark_definitions
        @info "Benchmark: $benchname"

        results = []
        @progress "Sweep" for p in ntproduct(; bench.paramaxes...)
            @info "Parameter: $(bench.paramasdata(p))"
            b = @benchmarkable(
                $(bench.run)(p, r),
                setup = begin
                    p = $p
                    rng = $(MersenneTwister(1234))
                    r = $(bench.prepare)(p, rng)
                end,
            )
            BenchmarkTools.warmup(b)
            BenchmarkTools.tune!(b; verbose = true)
            trial = run(b; verbose = true)
            push!(
                results,
                Dict(:trial => asdict(trial), :parameter => bench.paramasdata(p)),
            )
        end

        push!(benchmarks, Dict(:benchname => benchname, :results => results))
    end

    outputpath = "$outputstem.json"
    @info "Writing results to `$outputpath`"
    open(outputpath, write = true) do io
        JSON.print(
            io,
            Dict(
                :script => scriptname,
                :tags => append!([scriptname], tags),
                :benchmarks => benchmarks,
                :VERSION => string(VERSION),
                :nthreads => Threads.nthreads(),
            ),
        )
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
