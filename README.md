# ThreadsXBenchmarks

## Installation

```
] dev https://github.com/tkf/ThreadsXBenchmarks.jl
; cd ~/.julia/dev/ThreadsXBenchmarks
] activate .
```

## How to run

```julia
using ThreadsXBenchmarks
ThreadsXBenchmarks.run_all("PATH/TO/OUTPUT/DIRECTORY")
```

## How to load

```julia
include("scripts/plots.jl")
data = plotall("PATH/TO/OUTPUT/DIRECTORY")
data.sort_target     # DataFrame for sorting benchmarks (multi-thread)
data.sort_baseline   # DataFrame for sorting benchmarks (single-thread)
data.fold_target     # DataFrame for reduce benchmarks (multi-thread)
data.fold_baseline   # DataFrame for reduce benchmarks (single-thread)
data.sort_agg_plot   # vega-lite plot for sorting benchmarks
data.fold_agg_plot   # vega-lite plot for reduce benchmarks
```
