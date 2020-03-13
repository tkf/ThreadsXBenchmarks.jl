include("scaling_nthreads_target.jl")
using Setfield: @set!

function manual_symmetrize!(A, B)
    @argcheck size(A) == size(B)
    for j in axes(A, 2), i in axes(A, 1)
        @inbounds A[i, j] = (B[i, j] + B[j, i]) / 2
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    let benchmarks = BENCHMARKS

        # sort: use `alg = Base.QuickSort`
        @set! benchmarks[:sort].run = (p, r) -> sort!(r; alg = p.alg.value)
        @set! benchmarks[:sort].paramaxes.alg =
            [(label = "Base.QuickSort", value = Base.QuickSort)]
        @set! benchmarks[:sort].paramaxes.basesize = [nothing]
        @set! benchmarks[:sort].paramaxes.smallsize = [nothing]

        # foreach_symmetrize: use manual implementation
        @set! benchmarks[:foreach_symmetrize].run = (p, r) -> manual_symmetrize!(r.A, r.B)

        @set! benchmarks[:sum_sin].run = (p, r) -> sum(sin, r)
        @set! benchmarks[:findfirst].run = (p, r) -> findfirst(==(-1), r)
        @set! benchmarks[:unique].run = (p, r) -> unique(r)

        main(benchmark_definitions = benchmarks, tags = ["nthreads-baseline"])
    end
end
