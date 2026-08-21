# Coerce observed outcomes to 0/1

The same three forms
[`binary_response()`](https://camilleross.org/fancyfx/reference/binary_response.md)
accepts, and the same reading of each, so a
[`held_out()`](https://camilleross.org/fancyfx/reference/held_out.md)
pair and a model scored on a data frame agree about which class is
positive. Split out rather than shared with
[`binary_response()`](https://camilleross.org/fancyfx/reference/binary_response.md)
because that one reaches into `newdata` for a column named by the
model's formula, and here there is no model and no column.

## Usage

``` r
as_binary_outcome(observed)
```

## Arguments

- observed:

  Observed outcomes.

## Value

A 0/1 numeric vector.
