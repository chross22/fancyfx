# Build panel labels for a multi-panel figure

Build panel labels for a multi-panel figure

## Usage

``` r
panel_labels(labels, n)
```

## Arguments

- labels:

  What the caller asked for: `"a"` for lower-case letters, `"A"` for
  upper-case, `"1"` for numbers, `"none"`/`NULL` for no labels, or a
  character vector to use verbatim.

- n:

  How many panels there are.

## Value

A character vector of length `n`, or `NULL` for no labels.
