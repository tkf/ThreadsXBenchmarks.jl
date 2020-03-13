using VegaLite
using DataFrames
using Statistics

baseline_median = by(df[df.alg.=="Base.QuickSort", :], [:distribution]) do group
    @assert allunique(group.itime)
    group = group[group.itime.>1, :]
    (baseline_time = median(group.time),)
end

df_normalized = join(df[df.alg.!="Base.QuickSort", :], baseline_median, on = :distribution)
df_normalized[!, :normalized_time] = df_normalized.time ./ df_normalized.baseline_time
df_normalized[!, :speedup] = 1 ./ df_normalized.normalized_time

plt1 =
    df_normalized |> @vlplot(
        mark = {type = :point, tooltip = true},
        x = :nthreads,
        y = :speedup,
        color = :basesize,
        row = :alg,
        column = :distribution,
    )
#-

plt2 =
    df_normalized |> @vlplot(
        mark = {type = :point, tooltip = true},
        x = :nthreads,
        y = {field = :speedup, aggregate = :median},
        color = "basesize:n",
        row = :alg,
        column = :distribution,
    )
#-
