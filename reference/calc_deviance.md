# Deviance of a set of predictions

How badly the predictions miss, on the scale the model was fitted on.
Lower is better, and zero is a perfect fit.

## Usage

``` r
calc_deviance(
  observed,
  predicted,
  family = c("binomial", "poisson", "gaussian", "laplace"),
  weights = NULL,
  mean = TRUE
)
```

## Arguments

- observed:

  Observed outcomes.

- predicted:

  Predicted values, on the response scale.

- family:

  `"binomial"`, `"poisson"`, `"gaussian"`, or `"laplace"`.

- weights:

  Optional observation weights.

- mean:

  Whether to return the mean deviance per observation rather than the
  total.

## Value

A single number.

## Details

Deviance answers a question AUC cannot: AUC only cares about ranking,
and will not notice predictions that are ordered correctly but wrong.
Deviance penalises confident mistakes hardest, which is usually the
failure that matters.

It is most useful as a *relative* measure. Compare a model's deviance to
the null deviance – what you would get predicting the overall mean for
every observation – and the ratio is the proportion of deviance
explained, the quantity boosted regression tree work reports as a matter
of course.

## References

Elith, J., Leathwick, J. R., & Hastie, T. (2008). A working guide to
boosted regression trees. *Journal of Animal Ecology*, 77(4), 802-813.
[doi:10.1111/j.1365-2656.2008.01390.x](https://doi.org/10.1111/j.1365-2656.2008.01390.x)

## See also

[`threshold_metrics()`](https://camilleross.org/fancyfx/reference/threshold_metrics.md)
for discrimination,
[`calibration_estimates()`](https://camilleross.org/fancyfx/reference/calibration_estimates.md)
for whether the probabilities are honest.

Other evaluation plots:
[`calibration_estimates()`](https://camilleross.org/fancyfx/reference/calibration_estimates.md),
[`held_out()`](https://camilleross.org/fancyfx/reference/held_out.md),
[`permutation_importance()`](https://camilleross.org/fancyfx/reference/permutation_importance.md),
[`plotCalibration()`](https://camilleross.org/fancyfx/reference/plotCalibration.md),
[`plotImportance()`](https://camilleross.org/fancyfx/reference/plotImportance.md),
[`plotROC()`](https://camilleross.org/fancyfx/reference/plotROC.md),
[`plotThreshold()`](https://camilleross.org/fancyfx/reference/plotThreshold.md),
[`spatial_sorting_bias()`](https://camilleross.org/fancyfx/reference/spatial_sorting_bias.md),
[`threshold_metrics()`](https://camilleross.org/fancyfx/reference/threshold_metrics.md)

## Examples

``` r
set.seed(1)
dat <- data.frame(x = runif(300, 1, 10))
dat$y <- rbinom(300, 1, plogis(-3 + 0.6 * dat$x))
fit <- glm(y ~ x, data = dat, family = binomial)

fitted.deviance <- calc_deviance(dat$y, fitted(fit), "binomial")
null.deviance <- calc_deviance(dat$y, rep(mean(dat$y), nrow(dat)),
                               "binomial")

# Proportion of deviance explained
1 - fitted.deviance / null.deviance
#> [1] 0.2456978
```
