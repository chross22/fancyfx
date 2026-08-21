# Bin predictions and count how often the outcome occurred

Bin predictions and count how often the outcome occurred

## Usage

``` r
bin_calibration(observed, predicted, bins, binning, level)
```

## Arguments

- observed:

  0/1 numeric vector.

- predicted:

  Numeric vector of predicted probabilities.

- bins:

  Number of bins.

- binning:

  `"quantile"` or `"width"`.

- level:

  Level for the Wilson interval.

## Value

A data frame, one row per non-empty bin.
