# Check a scale name

`"auto"` is resolved by each
[`effect_estimates()`](https://camilleross.org/fancyfx/reference/effect_estimates.md)
method, not here: the natural scale differs by backend, and only the
method knows which it is.

## Usage

``` r
check_scale(scale)
```

## Arguments

- scale:

  the scale given

## Value

`scale`, unchanged
