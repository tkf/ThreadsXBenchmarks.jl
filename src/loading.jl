module Loading

import JSON
import Tables
using AtBackslash: @\
using BangBang
using Transducers

function as_sorted_namedtuple(d)
    xs = sort!(collect(d); by = first)
    (; (Symbol(k) => v for (k, v) in xs)...)
end

paths_to_rows_xf(; bench_xf = Map(identity), result_xf = Map(identity)) =
    Map(as_sorted_namedtuple ∘ JSON.parsefile) |> Zip(
        Map(x -> delete!!(x, :benchmarks)), # broadcast scalars
        MapCat(@\ _.benchmarks) |> Map(as_sorted_namedtuple),
    ) |> MapSplat(merge) |> bench_xf |> Zip(
        Map(x -> delete!!(x, :results)), # broadcast scalars
        MapCat(@\ _.results) |> Map(as_sorted_namedtuple),
    ) |> MapSplat(merge) |> result_xf |> Zip(
        Map(x -> delete!!(x, :trial)), # broadcast scalars
        MapCat() do x
            Tables.namedtupleiterator((
                time = x[:trial]["times"],
                gctime = x[:trial]["gctimes"],
                itime = 1:length(x[:trial]["times"]),
            ))
        end,
    ) |> MapSplat(merge)

results(jsonpath::AbstractString; kw...) = results([jsonpath]; kw...)
results(jsonpaths::AbstractVector{<:AbstractString}; kw...) =
    eduction(paths_to_rows_xf(; kw...), jsonpaths)

results_by_benchname(benchname::AbstractString, args...; kw...) =
    results_by_benchname(==(benchname), args...; kw...)

results_by_benchname(predicate, args...; kw...) = results(
    args...;
    bench_xf = Filter(@\ predicate(:benchname)),
    result_xf = Map(x -> merge(delete!!(x, :parameter), as_sorted_namedtuple(x.parameter))),
    kw...,
)

end  # module
