# Aggregate spatial values into hexagonal bins

Summarises covariates, model output or raw observations into a hexagonal
lattice. Works on a `SpatRaster` or on a data frame of points, and
returns the binned values rather than only a picture, so the result can
be analysed, joined or written out.

## Usage

``` r
hex_bin(
  x,
  value = NULL,
  coords = NULL,
  bins = 30,
  cellsize = NULL,
  fun = c("mean", "median", "sum", "sd", "min", "max", "count"),
  min.n = 1,
  layer = 1
)
```

## Arguments

- x:

  A `SpatRaster`, or a data frame of points.

- value:

  For a data frame, the column to summarise. Omit to count points
  instead. Ignored for a raster, which uses its first layer unless
  `layer` says otherwise.

- coords:

  For a data frame, the two coordinate columns. Defaults to the first
  pair of names found among the usual candidates.

- bins:

  Approximate number of hexagons across the x range. Ignored when
  `cellsize` is given.

- cellsize:

  Hexagon size, measured centre to vertex, in the units of the
  coordinates. Overrides `bins` when supplied.

- fun:

  How to summarise the values in each hexagon: `"mean"`, `"median"`,
  `"sum"`, `"sd"`, `"min"`, `"max"`, or `"count"`.

- min.n:

  Hexagons holding fewer than this many values are dropped. See Details.

- layer:

  For a raster, which layer to summarise.

## Value

A data frame with one row per hexagon: `.x` and `.y` for the centre,
`.value` for the summary, and `.n` for how many values it covers.
Carries a `"cellsize"` attribute.

## Details

Hexagons over squares for a reason worth stating: every neighbour of a
hexagon shares an edge and sits at the same distance, where a square
grid has neighbours at two different distances depending on whether they
meet at an edge or a corner. That makes hexagons better behaved for
anything that depends on adjacency, and it removes the visual grain a
square lattice imposes on a map.

Binning is also a claim about resolution. A projection raster drawn at
native resolution invites the reader to believe every pixel is
separately estimated, which is rarely true when the covariates were
interpolated from far coarser data. Aggregating to a cell size you can
defend is more honest than drawing detail the model does not have.

`min.n` exists because a hexagon holding one observation is not a
summary of anything, and on a map it is indistinguishable from one
holding a thousand. The returned `.n` column reports the count either
way.

## Coordinates and area

The lattice is built in whatever units the coordinates are in. For
projected coordinates that gives equal-area hexagons, which is what you
want. For unprojected longitude and latitude it does not: a degree of
longitude shortens toward the poles, so hexagons at the top of a domain
cover less ground than those at the bottom, and a count per hexagon is
not a density. `hex_bin()` says so once per session when handed lon/lat.
Project first if the areas matter.

## See also

[`plotHexbin()`](https://camilleross.org/fancyfx/reference/plotHexbin.md)
to draw it.

Other spatial plots:
[`ensemble_summary()`](https://camilleross.org/fancyfx/reference/ensemble_summary.md),
[`mess()`](https://camilleross.org/fancyfx/reference/mess.md),
[`niche_equivalency()`](https://camilleross.org/fancyfx/reference/niche_equivalency.md),
[`niche_overlap()`](https://camilleross.org/fancyfx/reference/niche_overlap.md),
[`plot.fancyfx_equivalency()`](https://camilleross.org/fancyfx/reference/plot.fancyfx_equivalency.md),
[`plotExtrapolation()`](https://camilleross.org/fancyfx/reference/plotExtrapolation.md),
[`plotHexbin()`](https://camilleross.org/fancyfx/reference/plotHexbin.md),
[`plotUncertainty()`](https://camilleross.org/fancyfx/reference/plotUncertainty.md),
[`thin_points()`](https://camilleross.org/fancyfx/reference/thin_points.md)

## Examples

``` r
set.seed(1)
points <- data.frame(x = runif(500, 0, 10), y = runif(500, 0, 10))
points$catch <- points$x + rnorm(500)

binned <- hex_bin(points, value = "catch", bins = 12)
head(binned)
#>         .x        .y    .value .n
#> 1 3.314135  7.175313  2.806464  4
#> 2 3.728402  7.892844  3.823368  4
#> 3 4.142669  8.610375  3.898482  3
#> 4 4.556936  9.327907  5.311916  1
#> 5 4.971203 10.045438  5.704435  5
#> 6 0.000000  1.435063 -1.375169  2

# Counts rather than a summary of some value
head(hex_bin(points, fun = "count", bins = 12))
#>         .x        .y .value .n
#> 1 3.314135  7.175313      4  4
#> 2 3.728402  7.892844      4  4
#> 3 4.142669  8.610375      3  3
#> 4 4.556936  9.327907      1  1
#> 5 4.971203 10.045438      5  5
#> 6 0.000000  1.435063      2  2
```
