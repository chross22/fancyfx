# Unwrap a fitted object that carries its GAM in a list element

[`gamm4::gamm4()`](https://rdrr.io/pkg/gamm4/man/gamm4.html) and
[`mgcv::gamm()`](https://rdrr.io/pkg/mgcv/man/gamm.html) return a list
holding the GAM alongside the mixed-model fit it was estimated through,
rather than a fitted model object. Nothing downstream can use the
wrapper: `marginaleffects` refuses the class outright, and
[`formula()`](https://rdrr.io/r/stats/formula.html) and
[`predict()`](https://rspatial.github.io/terra/reference/predict.html)
both fail on it. The `$gam` element is an ordinary `gam`, so unwrapping
makes every path work at once.

## Usage

``` r
unwrap_gam(model)
```

## Arguments

- model:

  A fitted model, wrapped or not.

## Value

The `$gam` element when there is one, otherwise `model` unchanged.

## Details

The random effects are left behind with the wrapper. That is the right
default and matches the rest of the package – the smooth is reported at
the population level – but it does mean the ribbon covers uncertainty in
the smooth alone.
