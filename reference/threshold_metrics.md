# Threshold-dependent classification metrics across every cutoff

Sweeps every threshold the predictions admit and reports what the model
would score at each one. The basis of
[`plotROC()`](https://camilleross.org/fancyfx/reference/plotROC.md) and
[`plotThreshold()`](https://camilleross.org/fancyfx/reference/plotThreshold.md),
and useful on its own for finding the cutoff a decision should actually
use.

## Usage

``` r
threshold_metrics(model, newdata, folds = NULL, ...)
```

## Arguments

- model:

  A fitted presence/absence model – one whose predictions are
  probabilities. See Details.

- newdata:

  Data to evaluate on. **Required, and it should not be the data the
  model was fitted to.** See the section below.

- folds:

  Optional vector of fold identifiers, one per row of `newdata`, as
  produced by a cross-validation scheme. When given, metrics are
  computed within each fold and the fold is recorded, so the spread
  across folds can be seen rather than averaged away. Using folds emits
  a note about what cross-validated metrics are and are not evidence of;
  see the section below.

- ...:

  Passed to [`stats::predict()`](https://rdrr.io/r/stats/predict.html).
  For a mixed model, `re.form` defaults to `NA` so held-out groups the
  model never saw do not error.

## Value

A data frame with one row per distinct threshold and columns
`.threshold`, `.sensitivity`, `.specificity`, `.tpr`, `.fpr`, `.tss`,
and `.fold` when folds were supplied. Carries attributes `auc`,
`prevalence`, `n`, and `in.sample`.

## Details

Every metric here is defined for a binary outcome and nothing else. AUC
and TSS applied to a Gaussian model of biomass would return a number,
and the number would be meaningless, so a non-binary response is refused
rather than scored.

The response may be `0`/`1`, a logical, or a two-level factor. For a
factor, the **second** level is taken as the positive case, matching how
[`stats::glm()`](https://rdrr.io/r/stats/glm.html) itself treats one.

`.tss` is the True Skill Statistic, `sensitivity + specificity - 1`,
also known as Youden's J. Unlike raw accuracy it is not inflated by a
rare positive class, which is why species distribution work reaches for
it.

## Evaluating on the training data

A model scored against the data it was fitted to flatters itself,
sometimes enormously. Passing the training data still works, because
refusing outright would be obstructive, but it warns, and every plot
built from the result is annotated as in-sample so the figure cannot be
mistaken for validation.

Cross-validation, through `folds`, sits between the two and is not a
substitute for the hold-out. The folds come from the same sample the
model was fitted on, so a cross-validated score speaks to how stable the
fit is, not to how it will behave somewhere new.

For spatial models the gap is wider still. Random folds are optimistic
when observations near each other are correlated, because a held-out
point usually has a near neighbour among the training folds – the model
has, in effect, already seen it. Spatially blocked folds are the honest
version, and the spread across folds is the part worth reading.
`threshold_metrics()` says as much, once per session, the first time
folds are used.

## References

Allouche, O., Tsoar, A., & Kadmon, R. (2006). Assessing the accuracy of
species distribution models: prevalence, kappa and the true skill
statistic (TSS). *Journal of Applied Ecology*, 43(6), 1223-1232.
[doi:10.1111/j.1365-2664.2006.01214.x](https://doi.org/10.1111/j.1365-2664.2006.01214.x)

## See also

[`plotROC()`](https://camilleross.org/fancyfx/reference/plotROC.md),
[`plotThreshold()`](https://camilleross.org/fancyfx/reference/plotThreshold.md),
[`plotImportance()`](https://camilleross.org/fancyfx/reference/plotImportance.md).

Other evaluation plots:
[`calc_deviance()`](https://camilleross.org/fancyfx/reference/calc_deviance.md),
[`calibration_estimates()`](https://camilleross.org/fancyfx/reference/calibration_estimates.md),
[`held_out()`](https://camilleross.org/fancyfx/reference/held_out.md),
[`permutation_importance()`](https://camilleross.org/fancyfx/reference/permutation_importance.md),
[`plotCalibration()`](https://camilleross.org/fancyfx/reference/plotCalibration.md),
[`plotImportance()`](https://camilleross.org/fancyfx/reference/plotImportance.md),
[`plotROC()`](https://camilleross.org/fancyfx/reference/plotROC.md),
[`plotThreshold()`](https://camilleross.org/fancyfx/reference/plotThreshold.md),
[`spatial_sorting_bias()`](https://camilleross.org/fancyfx/reference/spatial_sorting_bias.md)

## Examples

``` r
set.seed(1)
dat <- data.frame(x1 = runif(400, 1, 10), x2 = runif(400, 1, 10))
dat$y <- rbinom(400, 1, plogis(-3 + 0.6 * dat$x1))
train <- dat[1:200, ]
test <- dat[201:400, ]

fit <- glm(y ~ x1 + x2, data = train, family = binomial)
metrics <- threshold_metrics(fit, test)

attr(metrics, "auc")
#> [1] 0.8219822
# The cutoff that maximises the True Skill Statistic
metrics$.threshold[which.max(metrics$.tss)]
#> [1] 0.3717492
```
