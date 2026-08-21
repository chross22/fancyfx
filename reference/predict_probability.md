# Predict probabilities on new data

Predict probabilities on new data

## Usage

``` r
predict_probability(model, newdata, ...)
```

## Arguments

- model:

  A fitted model.

- newdata:

  Data to predict over.

- ...:

  Passed to [`stats::predict()`](https://rdrr.io/r/stats/predict.html).

## Value

A numeric vector of predicted probabilities.
