using VegaLite
using DataFrames
using Statistics

baseline_median = by(df_baseline, [:benchname]) do group
    @assert allunique(group.itime)
    group = group[group.itime.>1, :]
    (baseline_time = median(group.time),)
end

df_normalized = join(df_target, baseline_median, on = :benchname)
df_normalized[!, :normalized_time] = df_normalized.time ./ df_normalized.baseline_time
df_normalized[!, :speedup] = 1 ./ df_normalized.normalized_time

plt1 =
    df_normalized |> @vlplot(
        mark = {type = :point, tooltip = true},
        x = :nthreads,
        y = :speedup,
        color = :benchname,
        row = :benchname,
    )
#-

plt2 =
    df_normalized |> @vlplot(
        mark = {type = :point, tooltip = true},
        x = :nthreads,
        y = {field = :speedup, aggregate = :median},
        color = :benchname,
    )
#-
