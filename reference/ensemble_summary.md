# Summarise an ensemble of projection rasters

Collapses a stack whose layers are ensemble members – competing models,
emissions scenarios, bootstrap replicates – into one summary layer. The
spread statistics are the point: a projection map without one says only
what the ensemble guessed, not how much the members disagreed.

## Usage

``` r
ensemble_summary(
  x,
  statistic = c("sd", "cv", "range", "iqr", "mean", "median"),
  na.rm = FALSE
)
```

## Arguments

- x:

  A `SpatRaster` whose layers are ensemble members.

- statistic:

  What to compute across layers at each cell. `"sd"`, `"cv"`, `"range"`
  and `"iqr"` describe disagreement; `"mean"` and `"median"` describe
  the projection itself.

- na.rm:

  Whether to ignore members that are missing at a cell. See Details –
  the default is deliberately `FALSE`.

## Value

A single-layer `SpatRaster`.

## Details

`na.rm` defaults to `FALSE`, which is the opposite of most R summaries
and is deliberate. If one member is missing over part of the domain,
taking the spread of the members that remain reports a *narrower*
uncertainty exactly where the ensemble is least complete, and nothing on
the resulting map says so. Leaving those cells `NA` makes the gap
visible. Set `na.rm = TRUE` only once you know why the members differ in
coverage.

`"cv"` is the standard deviation over the mean. It is the natural choice
when members are on a count or density scale, where a spread of 5 means
something very different at a mean of 10 than at a mean of 1000. It is a
poor choice for probabilities, where the mean can approach zero and the
ratio explodes; use `"sd"` there.

## See also

[`plotUncertainty()`](https://camilleross.org/fancyfx/reference/plotUncertainty.md)
to draw it,
[`mess()`](https://camilleross.org/fancyfx/reference/mess.md) for
whether the projection is extrapolating in the first place.

Other spatial plots:
[`hex_bin()`](https://camilleross.org/fancyfx/reference/hex_bin.md),
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
if (requireNamespace("terra", quietly = TRUE)) {
  r <- terra::rast(nrows = 20, ncols = 20, vals = runif(400))
  ensemble <- c(r, r * 1.2, r * 0.7)
  names(ensemble) <- c("model1", "model2", "model3")

  ensemble_summary(ensemble, "sd")
}
#> class       : SpatRaster
#> size        : 20, 20, 1  (nrow, ncol, nlyr)
#> resolution  : 18, 9  (x, y)
#> extent      : -180, 180, -90, 90  (xmin, xmax, ymin, ymax)
#> coord. ref. : lon/lat WGS 84 (CRS84) (OGC:CRS84)
#> source(s)   : memory
#> name        :       sd
#> min value   : 0.000152
#> max value   : 0.250746
```
