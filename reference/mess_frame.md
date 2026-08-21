# MESS over a data frame of cells

MESS over a data frame of cells

## Usage

``` r
mess_frame(x, references, vars, limiting = FALSE)
```

## Arguments

- x:

  A data frame of covariates.

- references:

  Training values per covariate.

- vars:

  Covariate names.

- limiting:

  Whether to name the covariate responsible.

## Value

A data frame with `mess` and optionally `mess_variable`.
