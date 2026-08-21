# Are the model's predicted probabilities honest?

Bins predictions and compares the average prediction in each bin against
how often the outcome actually occurred. A well calibrated model that
says 0.7 is right about 70% of the time.

## Usage

``` r
calibration_estimates(
  model,
  newdata = NULL,
  bins = 10,
  binning = c("quantile", "width"),
  folds = NULL,
  level = 0.95,
  ...
)
```

## Arguments

- model:

  A fitted presence/absence model.

- newdata:

  Data to evaluate on. **Required, and it should not be the data the
  model was fitted to.** See
  [`threshold_metrics()`](https://camilleross.org/fancyfx/reference/threshold_metrics.md).

- bins:

  Number of bins.

- binning:

  `"quantile"` for bins holding equal numbers of observations, or
  `"width"` for bins of equal width across `[0, 1]`. See Details.

- folds:

  Optional fold identifiers, one per row of `newdata`. Binning is done
  within each fold. Using folds emits a note about what cross-validated
  metrics are evidence of.

- level:

  Level for the interval on each bin's observed frequency.

- ...:

  Passed to [`stats::predict()`](https://rdrr.io/r/stats/predict.html).

## Value

A data frame with one row per bin: `.bin`, `.predicted`, `.observed`,
`.lower`, `.upper`, `.n`, and `.fold` when folds were supplied. Carries
attributes `calibration`, `brier`, `n` and `in.sample`.

## Details

Calibration is a different question from discrimination, and a model can
be good at one and bad at the other. AUC only cares whether presences
are ranked above absences, so it is unchanged by any monotone rescaling
of the predictions – a model can have an excellent AUC while every
probability it reports is far too high. If those probabilities feed a
decision, an area calculation, or an expected count, calibration is the
property that matters and AUC will not reveal it.

`binning` trades two problems against each other. Equal-width bins are
easy to read but leave the extremes nearly empty, which is exactly where
miscalibration shows up, so the noisiest points sit where the
interesting behaviour is. Quantile bins put the same number of
observations in each, making every point equally reliable, at the cost
of bins whose widths vary. Quantile is the default for that reason. The
rug drawn by
[`plotCalibration()`](https://camilleross.org/fancyfx/reference/plotCalibration.md)
shows which regime you are in.

The interval on each bin is a Wilson score interval, not a normal
approximation. With few observations in a bin, or an observed frequency
near 0 or 1 – both routine here – the normal approximation produces
bounds outside `[0, 1]`, which would be a plot claiming something
impossible.

The `"calibration"` attribute holds the intercept and slope from
regressing the outcome on the logit of the prediction. A perfectly
calibrated model gives intercept 0 and slope 1. A slope below 1 means
predictions are too extreme – too close to 0 and 1 – which is the usual
signature of a model fitted on too little data for its flexibility.

## References

Harrell, F. E. (2015). *Regression Modeling Strategies* (2nd ed.).
Springer.
[doi:10.1007/978-3-319-19425-7](https://doi.org/10.1007/978-3-319-19425-7)

## See also

[`plotCalibration()`](https://camilleross.org/fancyfx/reference/plotCalibration.md)
to draw it,
[`threshold_metrics()`](https://camilleross.org/fancyfx/reference/threshold_metrics.md)
for discrimination.

Other evaluation plots:
[`calc_deviance()`](https://camilleross.org/fancyfx/reference/calc_deviance.md),
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
dat <- data.frame(x1 = runif(600, 1, 10), x2 = runif(600, 1, 10))
dat$y <- rbinom(600, 1, plogis(-3 + 0.6 * dat$x1))

fit <- glm(y ~ x1 + x2, data = dat[1:300, ], family = binomial)
cal <- calibration_estimates(fit, dat[301:600, ])

attr(cal, "calibration")   # intercept 0 and slope 1 would be perfect
#>   intercept       slope 
#> -0.05441074  0.81212476 
attr(cal, "brier")
#> [1] 0.1838627
```
