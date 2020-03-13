include("scaling_nthreads_target.jl")
using Setfield: @set!

if abspath(PROGRAM_FILE) == @__FILE__
    let benchmarks = copy(BENCHMARKS)
        @set! benchmarks[:sort].paramaxes.datasize =
            [100_000, 1_000_000, 10_000_000, 100_000_000]
        @set! benchmarks[:foreach_symmetrize].paramaxes.datasize = [1000, 10_000]

        main(benchmark_definitions = benchmarks, tags = ["datasize"])
    end
end
