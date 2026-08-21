# Draw a single raster layer as a ggplot panel

The shared body of the spatial plots: aggregate if too large to draw,
convert to a data frame, and set an aspect ratio that does not distort
the map.

## Usage

``` r
raster_panel(r, title, legend.lab, max.cells, theme)
```

## Arguments

- r:

  A single-layer `SpatRaster`.

- title:

  Plot title.

- legend.lab:

  Legend title.

- max.cells:

  Largest number of cells to draw.

- theme:

  A ggplot2 theme.

## Value

A ggplot2 object without a fill scale.
