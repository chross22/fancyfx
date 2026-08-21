# Multivariate environmental similarity surface

Where does a projection leave the conditions the model was fitted under?
Negative values mark cells outside the training range of at least one
covariate – places where the model is extrapolating rather than
interpolating, and where its predictions are guesses dressed as
estimates.

## Usage

``` r
mess(x, training, vars = NULL, limiting = FALSE)
```

## Arguments

- x:

  A `SpatRaster` of covariates to project onto. Layer names must match
  the columns of `training`.

- training:

  A data frame of the covariate values the model was fitted on, or a
  fitted model to take them from.

- vars:

  Covariates to consider. Defaults to those common to both.

- limiting:

  Whether to also report the covariate responsible for each cell's
  score. `FALSE` by default, so the returned shape is unchanged.

## Value

For a `SpatRaster`, a `SpatRaster` named `mess`, gaining a categorical
`mess_variable` layer when `limiting = TRUE`. For a data frame, a data
frame with a `mess` column and, when `limiting = TRUE`, a
`mess_variable` column. Negative values are novel.

## Details

Implements the MESS of Elith, Kearney and Phillips (2010). For each cell
and each covariate, similarity is 100 when the value sits at the median
of the training data and falls to 0 at its minimum and maximum, going
negative beyond them in proportion to how far outside the range the
value lies. The surface reports the **minimum** across covariates, so a
cell is flagged as novel if any single covariate is out of range – which
is the useful convention, since one novel variable is enough to
invalidate a prediction.

What it does not detect is novel *combinations* of covariates that are
each individually within range. A cell can be perfectly ordinary on
every axis separately and still be somewhere the model has never seen,
and MESS will report it as similar. Treat a non-negative surface as the
absence of one specific problem, not as a licence to project.

## Which covariate is responsible

The surface says a cell is novel; `limiting = TRUE` says what made it
so. That is usually the actionable half – "this shelf is extrapolated"
is a shrug, "extrapolated because its chlorophyll is higher than any
training record" is a decision about whether to widen the training
window or clip the map. It names the covariate with the lowest
similarity, which is the one the minimum was taken from.

## Rasters and data frames

`x` may be a `SpatRaster` of covariate layers or a plain data frame of
covariate columns, and the return follows the input. The data frame form
is for pipelines that hold their projection as a table of cells rather
than as a raster, which is common enough that requiring a round trip
through `terra` to score it would be a tax rather than a service.

## References

Elith, J., Kearney, M., & Phillips, S. (2010). The art of modelling
range-shifting species. *Methods in Ecology and Evolution*, 1(4),
330-342.
[doi:10.1111/j.2041-210X.2010.00036.x](https://doi.org/10.1111/j.2041-210X.2010.00036.x)

## See also

[`plotExtrapolation()`](https://camilleross.org/fancyfx/reference/plotExtrapolation.md)
to draw it,
[`ensemble_summary()`](https://camilleross.org/fancyfx/reference/ensemble_summary.md)
for disagreement between members.

Other spatial plots:
[`ensemble_summary()`](https://camilleross.org/fancyfx/reference/ensemble_summary.md),
[`hex_bin()`](https://camilleross.org/fancyfx/reference/hex_bin.md),
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
  set.seed(1)
  training <- data.frame(temp = rnorm(200, 10, 2), depth = runif(200, 0, 100))

  covariates <- c(
    terra::rast(nrows = 20, ncols = 20, vals = rnorm(400, 12, 3)),
    terra::rast(nrows = 20, ncols = 20, vals = runif(400, -20, 140))
  )
  names(covariates) <- c("temp", "depth")

  novelty <- mess(covariates, training)
  # Cells below zero are outside the training range of some covariate.
}
```
