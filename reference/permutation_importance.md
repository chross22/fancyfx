# Permutation importance for a fitted model

Shuffles one predictor at a time and measures how much worse the model
gets. Model-agnostic: it needs nothing from the model but the ability to
predict, so it works the same for a GAM, a GLM, a mixed model or a
Bayesian fit, and the numbers mean the same thing across all of them.

## Usage

``` r
permutation_importance(
  model,
  newdata,
  vars = NULL,
  n.perm = 10,
  metric = c("auto", "auc", "rmse"),
  seed = 1,
  ...
)
```

## Arguments

- model:

  A fitted model.

- newdata:

  Data to measure importance on. **Required, and it should not be the
  data the model was fitted to** – importance measured in-sample rewards
  a variable for the overfitting it enabled. See
  [`threshold_metrics()`](https://camilleross.org/fancyfx/reference/threshold_metrics.md)
  for the same caveat about evaluation data.

- vars:

  Predictors to permute. Defaults to every predictor in the model.

- n.perm:

  Number of permutations per variable. More is steadier and slower; the
  default is a reasonable compromise for a plot.

- metric:

  `"auto"`, `"auc"`, or `"rmse"`. `"auto"` picks AUC for a binary
  response and RMSE otherwise.

- seed:

  Random seed. Set by default because permutation importance is
  stochastic, and an unseeded figure cannot be reproduced.

- ...:

  Passed to [`stats::predict()`](https://rdrr.io/r/stats/predict.html).

## Value

A data frame with one row per variable per permutation: `.variable`,
`.permutation`, `.importance`. Carries attributes `metric`, `baseline`,
and `in.sample`.

## Details

Importance is the loss of performance when a variable is made
uninformative: its column is shuffled, breaking any relationship with
the response while leaving its marginal distribution intact, and the
model is scored again. For AUC importance is the drop; for RMSE it is
the increase. Either way, larger means the model was relying on that
variable more, and a value at or below zero means the model was not
using it usefully at all.

Two things this measure does not do, both worth knowing before reading
the plot:

- **Correlated predictors share credit unevenly.** If two variables
  carry much the same information, permuting either one alone barely
  hurts, because the other still carries it. Both look unimportant, and
  the pair is not. This bites hard on environmental covariates, which
  are routinely collinear.

- **It measures use, not effect.** A variable can be important here and
  have an effect too small to matter, or the reverse. Read it beside
  [`plotEffects()`](https://camilleross.org/fancyfx/reference/plotEffects.md),
  not instead of it.

## References

Breiman, L. (2001). Random forests. *Machine Learning*, 45(1), 5-32.
[doi:10.1023/A:1010933404324](https://doi.org/10.1023/A%3A1010933404324)

## See also

[`plotImportance()`](https://camilleross.org/fancyfx/reference/plotImportance.md)
to draw it,
[`plotEffects()`](https://camilleross.org/fancyfx/reference/plotEffects.md)
for the shape of an effect rather than its weight.

Other evaluation plots:
[`calc_deviance()`](https://camilleross.org/fancyfx/reference/calc_deviance.md),
[`calibration_estimates()`](https://camilleross.org/fancyfx/reference/calibration_estimates.md),
[`held_out()`](https://camilleross.org/fancyfx/reference/held_out.md),
[`plotCalibration()`](https://camilleross.org/fancyfx/reference/plotCalibration.md),
[`plotImportance()`](https://camilleross.org/fancyfx/reference/plotImportance.md),
[`plotROC()`](https://camilleross.org/fancyfx/reference/plotROC.md),
[`plotThreshold()`](https://camilleross.org/fancyfx/reference/plotThreshold.md),
[`spatial_sorting_bias()`](https://camilleross.org/fancyfx/reference/spatial_sorting_bias.md),
[`threshold_metrics()`](https://camilleross.org/fancyfx/reference/threshold_metrics.md)

## Examples

``` r
set.seed(1)
dat <- data.frame(x1 = runif(400, 1, 10), x2 = runif(400, 1, 10))
dat$y <- rbinom(400, 1, plogis(-3 + 0.6 * dat$x1))

fit <- glm(y ~ x1 + x2, data = dat[1:200, ], family = binomial)
imp <- permutation_importance(fit, dat[201:400, ], n.perm = 5)

aggregate(.importance ~ .variable, data = imp, FUN = mean)
#>   .variable .importance
#> 1        x1 0.318171817
#> 2        x2 0.005780578
```
