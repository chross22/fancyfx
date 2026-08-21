# Plot a calibration curve with a rug of where predictions fall

Binned predictions against observed frequency, with the diagonal as the
reference: a model that says 0.7 should be right about 70% of the time.
The rug above shows where the predictions actually are, which is what
tells you whether a bin near the extremes is worth reading at all.

## Usage

``` r
plotCalibration(
  model,
  newdata = NULL,
  bins = 10,
  binning = c("quantile", "width"),
  folds = NULL,
  level = 0.95,
  title = "",
  show.stats = TRUE,
  rug.type = c("histogram", "density"),
  rug.bins = 30,
  theme = theme_fancyfx(),
  palette = fancyfx_palette(),
  colour = fancyfx_palette(1),
  ...
)
```

## Arguments

- model:

  A fitted presence/absence model.

- newdata:

  Data to evaluate on. Required; see
  [`threshold_metrics()`](https://camilleross.org/fancyfx/reference/threshold_metrics.md).

- bins:

  Number of bins.

- binning:

  `"quantile"` (the default) or `"width"`.

- folds:

  Optional fold identifiers, one per row of `newdata`.

- level:

  Level for the interval on each bin.

- title:

  Plot title, optional.

- show.stats:

  Whether to report the calibration intercept and slope on the plot.

- rug.type:

  Type of rug drawn above the curve.

- rug.bins:

  Number of bins for a histogram rug.

- theme:

  A ggplot2 theme. Defaults to
  [`theme_fancyfx()`](https://camilleross.org/fancyfx/reference/theme_fancyfx.md).

- palette:

  Colours used for fold curves. Defaults to
  [`fancyfx_palette()`](https://camilleross.org/fancyfx/reference/fancyfx_palette.md).

- colour:

  Colour of the curve when there are no folds.

- ...:

  Passed to
  [`calibration_estimates()`](https://camilleross.org/fancyfx/reference/calibration_estimates.md)
  and on to [`stats::predict()`](https://rdrr.io/r/stats/predict.html).

## Value

A `patchwork` object: the rug above, the calibration curve below.

## Details

The rug is the same idea as in
[`plotEffects()`](https://camilleross.org/fancyfx/reference/plotEffects.md),
and matters more here than almost anywhere else. Calibration is usually
worst at the extremes, and the extremes are usually where the fewest
predictions are, so the most eye-catching departures from the diagonal
are often the least trustworthy points on the plot. The rug shows that
directly, and the interval on each bin shows it again.

See
[`calibration_estimates()`](https://camilleross.org/fancyfx/reference/calibration_estimates.md)
for why quantile binning is the default, and for what the reported
intercept and slope mean.

## See also

[`calibration_estimates()`](https://camilleross.org/fancyfx/reference/calibration_estimates.md)
for the numbers,
[`plotROC()`](https://camilleross.org/fancyfx/reference/plotROC.md) for
discrimination, which is a different question.

Other evaluation plots:
[`calc_deviance()`](https://camilleross.org/fancyfx/reference/calc_deviance.md),
[`calibration_estimates()`](https://camilleross.org/fancyfx/reference/calibration_estimates.md),
[`held_out()`](https://camilleross.org/fancyfx/reference/held_out.md),
[`permutation_importance()`](https://camilleross.org/fancyfx/reference/permutation_importance.md),
[`plotImportance()`](https://camilleross.org/fancyfx/reference/plotImportance.md),
[`plotROC()`](https://camilleross.org/fancyfx/reference/plotROC.md),
[`plotThreshold()`](https://camilleross.org/fancyfx/reference/plotThreshold.md),
[`spatial_sorting_bias()`](https://camilleross.org/fancyfx/reference/spatial_sorting_bias.md),
[`threshold_metrics()`](https://camilleross.org/fancyfx/reference/threshold_metrics.md)

## Examples

``` r
set.seed(1)
dat <- data.frame(x1 = runif(600, 1, 10), x2 = runif(600, 1, 10))
dat$y <- rbinom(600, 1, plogis(-3 + 0.6 * dat$x1))

fit <- glm(y ~ x1 + x2, data = dat[1:300, ], family = binomial)
plotCalibration(fit, dat[301:600, ])

```
