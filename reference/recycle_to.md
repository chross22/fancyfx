# Recycle a per-panel argument to the number of panels

Recycled explicitly rather than by R's rules, so a length that happens
to divide into the number of panels but was not meant to be recycled is
an error rather than a silently rearranged plot.

## Usage

``` r
recycle_to(value, n, what, units)
```

## Arguments

- value:

  The argument given.

- n:

  How many panels there are.

- what:

  What to call the argument in the error message.

- units:

  What to call the panels in the error message.

## Value

`value`, of length `n`.
