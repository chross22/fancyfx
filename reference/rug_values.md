# The values a rug is drawn from

A column when `var` names one, and otherwise the term evaluated in the
data – which is what makes a rug possible under `s(log10(depth))` or
`s(I(x^2))`. Evaluated in the data frame alone, with no enclosing
environment, so that a term naming a column that is not there cannot
silently pick up a variable of the same name from the caller and draw a
rug of something else entirely.

## Usage

``` r
rug_values(dat, var)
```

## Arguments

- dat:

  Raw data.

- var:

  A column name, or a term to evaluate in `dat`.

## Value

A numeric vector.
