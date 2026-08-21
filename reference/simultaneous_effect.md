# A simultaneous confidence band for a smooth

A pointwise interval covers the true value at each x separately, with
the stated probability at each one. It does not cover the whole curve
with that probability – across a smooth evaluated at a hundred points,
the true function will stray outside a pointwise 95% band far more often
than 5% of the time. Any claim about the *shape* of a smooth, which is
usually the reason for drawing one, is a claim about the whole curve,
and wants a band that covers the whole curve.

## Usage

``` r
simultaneous_effect(model, var, level, nsim, seed, ...)
```

## Arguments

- model:

  A fitted model gratia understands.

- var:

  Name of the smoothed predictor.

- level:

  Interval level.

- nsim:

  Number of posterior simulations used to find the critical value.

- seed:

  Random seed. The band is simulated, so an unseeded figure cannot be
  redrawn exactly.

- ...:

  Passed to
  [`gratia::confint.gam()`](https://gavinsimpson.github.io/gratia/reference/confint.gam.html).

## Value

A standardized effect frame.
