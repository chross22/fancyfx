# Coerce the accepted inputs to points with a value

Coerce the accepted inputs to points with a value

## Usage

``` r
hex_input(x, value, coords, layer)
```

## Arguments

- x:

  A `SpatRaster` or data frame.

- value:

  Column to summarise, for a data frame.

- coords:

  Coordinate columns, for a data frame.

- layer:

  Layer to summarise, for a raster.

## Value

A list with `x`, `y`, `value` and `lonlat`.
