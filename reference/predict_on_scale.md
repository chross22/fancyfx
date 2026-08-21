# Ask marginaleffects for predictions on a given scale

Wraps the backend call for two reasons: to prefer an interval
construction that respects the bounds of the response, and to turn the
backend's complaint about an unsupported scale into advice.

## Usage

``` r
predict_on_scale(model, newdata, scale, interval, level, ...)
```

## Arguments

- model:

  A fitted model.

- newdata:

  The grid to predict over.

- scale:

  `"link"` or `"response"` (already resolved from `"auto"`).

- interval:

  `"se"` or `"ci"`.

- level:

  Confidence level.

- ...:

  Passed to
  [`marginaleffects::predictions()`](https://rdrr.io/pkg/marginaleffects/man/predictions.html).

## Value

The `predictions` object.
