# The covariates a MESS surface can be built from

The covariates a MESS surface can be built from

## Usage

``` r
mess_vars(x, training, vars, raster)
```

## Arguments

- x:

  A `SpatRaster` or data frame of covariates.

- training:

  Training data.

- vars:

  Requested covariates, or `NULL` for the ones in common.

- raster:

  Whether `x` is a raster, for the error wording.

## Value

A character vector of covariate names.
