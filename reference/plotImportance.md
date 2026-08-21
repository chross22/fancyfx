# Plot permutation importance

One row per predictor, ordered by importance, showing the spread across
permutations rather than a single bar. The spread is the point: a
variable whose importance swings between permutations has not been shown
to matter, and a bar chart of means would hide that.

## Usage

``` r
plotImportance(
  model,
  newdata,
  vars = NULL,
  n.perm = 10,
  metric = c("auto", "auc", "rmse"),
  seed = 1,
  title = "",
  xlab = NULL,
  theme = theme_fancyfx(),
  colour = fancyfx_palette(1),
  ...
)
```

## Arguments

- model:

  A fitted model.

- newdata:

  Data to measure importance on. Required; see
  [`permutation_importance()`](https://camilleross.org/fancyfx/reference/permutation_importance.md).

- vars:

  Predictors to permute. Defaults to every predictor in the model.

- n.perm:

  Number of permutations per variable.

- metric:

  `"auto"`, `"auc"`, or `"rmse"`.

- seed:

  Random seed.

- title:

  Plot title, optional.

- xlab:

  Label for the importance axis. Defaults to naming the metric.

- theme:

  A ggplot2 theme. Defaults to
  [`theme_fancyfx()`](https://camilleross.org/fancyfx/reference/theme_fancyfx.md).

- colour:

  Colour for the points and ranges.

- ...:

  Passed to
  [`permutation_importance()`](https://camilleross.org/fancyfx/reference/permutation_importance.md)
  and on to [`stats::predict()`](https://rdrr.io/r/stats/predict.html).

## Value

A ggplot2 object.

## Details

Each variable gets a point at its mean importance and a line spanning
the permutations. The dashed zero line is the reference: a variable
whose range crosses it did no measurable work, since shuffling it left
the model no worse than it already was.

Read this beside
[`plotEffects()`](https://camilleross.org/fancyfx/reference/plotEffects.md)
rather than instead of it, and see
[`permutation_importance()`](https://camilleross.org/fancyfx/reference/permutation_importance.md)
for what correlated predictors do to the ordering – collinear covariates
make each other look unimportant.

## See also

[`permutation_importance()`](https://camilleross.org/fancyfx/reference/permutation_importance.md)
for the numbers,
[`plotEffects()`](https://camilleross.org/fancyfx/reference/plotEffects.md)
for the shape of each effect.

Other evaluation plots:
[`calc_deviance()`](https://camilleross.org/fancyfx/reference/calc_deviance.md),
[`calibration_estimates()`](https://camilleross.org/fancyfx/reference/calibration_estimates.md),
[`held_out()`](https://camilleross.org/fancyfx/reference/held_out.md),
[`permutation_importance()`](https://camilleross.org/fancyfx/reference/permutation_importance.md),
[`plotCalibration()`](https://camilleross.org/fancyfx/reference/plotCalibration.md),
[`plotROC()`](https://camilleross.org/fancyfx/reference/plotROC.md),
[`plotThreshold()`](https://camilleross.org/fancyfx/reference/plotThreshold.md),
[`spatial_sorting_bias()`](https://camilleross.org/fancyfx/reference/spatial_sorting_bias.md),
[`threshold_metrics()`](https://camilleross.org/fancyfx/reference/threshold_metrics.md)

## Examples

``` r
set.seed(1)
dat <- data.frame(x1 = runif(400, 1, 10), x2 = runif(400, 1, 10),
                  x3 = runif(400, 1, 10))
dat$y <- rbinom(400, 1, plogis(-3 + 0.6 * dat$x1))

fit <- glm(y ~ x1 + x2 + x3, data = dat[1:200, ], family = binomial)
plotImportance(fit, dat[201:400, ], n.perm = 5)

```
