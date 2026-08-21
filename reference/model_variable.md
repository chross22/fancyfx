# Recover a predictor's observed values from a fitted model

Used to choose the range the effect is evaluated over. Read from the
model rather than from the user's `dat`, so the grid can never extend
past where the model was actually fitted.

## Usage

``` r
model_variable(model, var, data = NULL)
```

## Arguments

- model:

  A fitted model.

- var:

  Name of the predictor, as a string.

- data:

  Optional data to fall back on when the model does not keep the frame
  it was fitted with.

## Value

The observed values of `var`.
