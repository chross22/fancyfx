# Identify the factor a set of smooths is split by

A factor-smooth interaction – `s(x, by = f)` – is one smooth per level
of `f`, and `gratia` returns them stacked in a single frame. Without
separating them, `geom_line()` joins the end of one level's curve to the
start of the next and draws a zigzag that looks like a single wildly
varying smooth.

## Usage

``` r
smooth_group(est)
```

## Arguments

- est:

  A
  [`gratia::smooth_estimates()`](https://gavinsimpson.github.io/gratia/reference/smooth_estimates.html)
  frame, as a data frame.

## Value

A factor of level labels, or `NULL` when the smooth is not split.
