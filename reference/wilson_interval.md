# Wilson score interval for a binomial proportion

Used in place of a normal approximation, which with few observations or
a proportion near 0 or 1 – both routine in a calibration bin – produces
bounds outside `[0, 1]`.

## Usage

``` r
wilson_interval(k, n, level)
```

## Arguments

- k:

  Number of successes.

- n:

  Number of trials.

- level:

  Confidence level.

## Value

A length-2 numeric vector.
