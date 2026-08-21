# Check an interval name

`"cri"` is accepted as a name for the same computation: under a Bayesian
fit the backend returns a credible interval, and a user who writes
`"cri"` to say so should not be met with an error.

## Usage

``` r
check_interval(interval)
```

## Arguments

- interval:

  the interval given

## Value

`interval`, with `"cri"` normalised to `"ci"`
