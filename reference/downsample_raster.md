# Aggregate a raster that is too large to draw cell by cell

Aggregate a raster that is too large to draw cell by cell

## Usage

``` r
downsample_raster(r, max.cells)
```

## Arguments

- r:

  A `SpatRaster`.

- max.cells:

  Largest number of cells to keep.

## Value

A list with the possibly-aggregated `raster` and the `factor` used.
