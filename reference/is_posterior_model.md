# Is this model summarised from posterior draws?

Such models report an interval computed from the draws and no standard
error, so a `+/- 1 SE` ribbon is not something they can produce.

## Usage

``` r
is_posterior_model(model)
```

## Arguments

- model:

  A fitted model.

## Value

`TRUE` for a Bayesian fit, `FALSE` otherwise.
