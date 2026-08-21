# Smooth labels involving a given variable

A factor-smooth interaction contributes several labels for one variable
– `s(x):fa`, `s(x):fb` and so on – so this returns all of them.

## Usage

``` r
smooth_labels(model, var)
```

## Arguments

- model:

  A fitted model gratia understands.

- var:

  Name of the smoothed predictor.

## Value

A character vector of smooth labels.
