# Does this model have random effects?

Checked by class rather than by inspecting the fit, because the answer
is needed before any prediction is attempted. Covers the mixed-model
packages marginaleffects supports and this package has been tested
against.

## Usage

``` r
has_random_effects(model)
```

## Arguments

- model:

  A fitted model.

## Value

`TRUE` for a mixed model, `FALSE` otherwise.
