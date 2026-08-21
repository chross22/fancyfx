# Predictor names for a fitted model

Read from the model's terms rather than its formula, so a term written
as `s(x, by = f)` contributes `x` and `f` and not the call around them.

## Usage

``` r
model_predictors(model)
```

## Arguments

- model:

  A fitted model.

## Value

A character vector of predictor names.
