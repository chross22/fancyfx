# Calibration intercept and slope

Regresses the outcome on the logit of the prediction. Intercept 0 and
slope 1 is perfect; a slope below 1 means the predictions are too
extreme.

## Usage

``` r
calibration_fit(observed, predicted)
```

## Arguments

- observed:

  0/1 numeric vector.

- predicted:

  Numeric vector of predicted probabilities.

## Value

A named numeric vector, or `NA`s if the fit fails.
