# Sweep every threshold the predictions admit

Exact rather than gridded: the curve only changes at observed prediction
values, so those are the thresholds worth evaluating, and a fixed grid
would either miss corners or waste points on flat stretches.

## Usage

``` r
sweep_thresholds(observed, predicted)
```

## Arguments

- observed:

  0/1 numeric vector.

- predicted:

  Numeric vector of predicted probabilities.

## Value

A data frame of metrics, one row per threshold.
