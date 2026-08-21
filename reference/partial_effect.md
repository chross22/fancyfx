# The partial effect of a smooth, via gratia

Shared by every model class gratia can report smooths for, so those
classes cannot drift apart in what they compute or how they fail.

## Usage

``` r
partial_effect(
  model,
  var,
  interval,
  level,
  n = 100,
  nsim = 10000,
  seed = 1,
  ...
)
```

## Arguments

- model:

  A fitted model gratia understands.

- var:

  Name of the smoothed predictor.

- interval:

  `"se"` or `"ci"` (already resolved).

- level:

  Interval level.

- n:

  Number of points to evaluate the smooth at.

- ...:

  Passed to
  [`gratia::smooth_estimates()`](https://gavinsimpson.github.io/gratia/reference/smooth_estimates.html),
  less `data`; see below.

## Value

A standardized effect frame.
