# Is this the data the model was fitted to?

Is this the data the model was fitted to?

## Usage

``` r
is_training_data(model, newdata)
```

## Arguments

- model:

  A fitted model.

- newdata:

  Data to compare against the model's own frame.

## Value

`TRUE`, `FALSE`, or `NA` when the model does not expose its frame.
