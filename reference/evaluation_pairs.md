# Line up observed outcomes against predicted probabilities

The shared prologue for every evaluation function: unwrap the model,
pull the response out of `newdata`, predict, drop incomplete rows, and
say something if the data turns out to be what the model was fitted on.
Extracted so the rules about evaluation data are enforced in one place
and cannot drift between functions.

## Usage

``` r
evaluation_pairs(
  model,
  newdata,
  folds = NULL,
  require.both.classes = TRUE,
  ...
)
```

## Arguments

- model:

  A fitted model.

- newdata:

  Data to evaluate on.

- folds:

  Optional fold identifiers, one per row of `newdata`.

- require.both.classes:

  Whether to refuse data containing only one outcome class.

- ...:

  Passed to [`stats::predict()`](https://rdrr.io/r/stats/predict.html).

## Value

A list with `observed`, `predicted`, `folds`, `complete` and
`in.sample`.
