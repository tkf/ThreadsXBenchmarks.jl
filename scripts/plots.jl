using AtBackslash: @\
using DataFrames
using Glob
using NamedTupleTools: @namedtuple
using Statistics
using ThreadsXBenchmarks
using UnPack: @unpack
using VegaLite

loadall(datadir) = (
    sort_target = copy(
        DataFrame,
        ThreadsXBenchmarks.Loading.results_by_benchname(
            "sort",
            readdir(glob"scaling_nthreads-*.json", datadir),
        ),
    ),
    sort_baseline = copy(
        DataFrame,
        ThreadsXBenchmarks.Loading.results_by_benchname(
            "sort",
            readdir(glob"scaling_nthreads_baseline.json", datadir),
        ),
    ),
    fold_target = copy(
        DataFrame,
        ThreadsXBenchmarks.Loading.results_by_benchname(
            !=("sort"),
            readdir(glob"scaling_nthreads-*.json", datadir),
        ),
    ),
    fold_baseline = copy(
        DataFrame,
        ThreadsXBenchmarks.Loading.results_by_benchname(
            !=("sort"),
            readdir(glob"scaling_nthreads_baseline.json", datadir),
        ),
    ),
)

function joinbaseline(target, baseline, on, agg)
    baseline_agg = by(baseline, on) do group
        @assert allunique(group.itime)
        # group = group[group.itime.>1, :]
        (baseline_time = agg(group.time),)
    end

    normalized = join(target, baseline_agg, on = on)
    normalized[!, :normalized_time] = normalized.time ./ normalized.baseline_time
    normalized[!, :speedup] = 1 ./ normalized.normalized_time

    return normalized
end

plotall(datadir::AbstractString; kw...) = plotall(loadall(datadir); kw...)

function plotall(data; agg = median)
    @unpack sort_target, sort_baseline, fold_target, fold_baseline = data

    sort_normalized =
        joinbaseline(sort_target, sort_baseline, [:distribution, :datasize], agg)
    fold_normalized = joinbaseline(fold_target, fold_baseline, [:benchname, :datasize], agg)

    fold_normalized = by(fold_normalized, [:benchname]) do group
        datasizes = sort!(unique(group.datasize))
        df = DataFrame(group)
        df[!, :datasize_label] = findfirst.((==).(group.datasize), Ref(datasizes))
        df
    end

    # Smaller `datasize` look better:
    sort_normalized = sort_normalized[sort_normalized.datasize.==1_000_000, :]

    # Larger `datasize` look better:
    fold_normalized = fold_normalized[fold_normalized.datasize_label.==2, :]

    sort_raw_plot = nothing
    sort_raw_plot = @vlplot(
        mark = {type = :point, tooltip = true},
        x = :nthreads,
        y = :speedup,
        color = :alg,
        row = :distribution,
        column = :datasize,
        data = sort_normalized,
    )

    sort_agg_plot = @vlplot(
        facet = {
            column = {field = :distribution, type = :nominal},
            # row = {field = :datasize, type = :nominal},
        },
        spec = {
            layer = [
                {
                    mark = {type = :point, tooltip = true},
                    encoding = {
                        x = {field = :nthreads},
                        y = {field = :speedup, axis = {title = "$agg(speedup)"}},
                        color = {field = :alg},
                    },
                },
                {
                    mark = {type = :rule, color = :black},
                    data = {values = [{ref = 1}]},
                    encoding = {y = {field = :ref, type = :quantitative}},
                },
            ],
        },
        data = by(
            sort_normalized,
            [:nthreads, :basesize, :alg, :distribution, :datasize];
            speedup = :speedup => agg,
        ),
    )

    fold_raw_plot = @vlplot(
        mark = {type = :point, tooltip = true},
        x = :nthreads,
        y = :speedup,
        color = :benchname,
        row = :benchname,
        column = :datasize,
        data = fold_normalized,
    )

    fold_agg_plot = @vlplot(
        layer = [
            {
                mark = {type = :point, tooltip = true},
                encoding = {
                    x = {field = :nthreads},
                    y = {field = :speedup, axis = {title = "$agg(speedup)"}},
                    color = {field = :benchname},
                },
            },
            {
                mark = {type = :rule, color = :black},
                data = {values = [{ref = 1}]},
                encoding = {y = {field = :ref, type = :quantitative}},
            },
        ],
        data = by(fold_normalized, [:nthreads, :benchname]; speedup = :speedup => agg),
    )

    return @namedtuple(data..., sort_raw_plot, sort_agg_plot, fold_raw_plot, fold_agg_plot)
end
