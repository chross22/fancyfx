# Assemble the standardized effect frame

Assemble the standardized effect frame

## Usage

``` r
standardize_effect(x, estimate, lower, upper, quantity, group = NULL)
```

## Arguments

- x, estimate, lower, upper:

  Equal-length numeric vectors.

- quantity:

  What was computed, for the y-axis label.

- group:

  Optional factor splitting the effect into separate curves, as for a
  factor-smooth interaction. `NULL` for a single curve.

## Value

A data frame ordered by `.x` within `.group`, with `quantity` attached.
