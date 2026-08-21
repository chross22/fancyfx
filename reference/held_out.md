# Evaluate predictions you already have

Every evaluation function here takes a fitted model and re-predicts.
That is the right default – it keeps the scored predictions and the
model provably in step – but it assumes the caller is holding a model
that can reproduce them, and a cross-validated workflow is not.

## Usage

``` r
held_out(observed, predicted, in.sample = FALSE)
```

## Arguments

- observed:

  Observed outcomes: `0`/`1`, a logical, or a two-level factor whose
  **second** level is the positive case, matching how
  [`stats::glm()`](https://rdrr.io/r/stats/glm.html) treats one.

- predicted:

  Predicted probabilities, one per element of `observed`.

- in.sample:

  Whether these predictions were made on the data the model was fitted
  to. `FALSE` by default; set `TRUE` and every plot built from them is
  annotated as in-sample, exactly as the model path would.

## Value

An object of class `fancyfx_held_out`, accepted wherever a model is.

## Details

Under k-fold cross-validation each observation is predicted by the one
fold model that did not see it. The honest predictions are therefore
spread across `k` models, none of which is the final fit, and by the
time a pipeline has a single model to hand it has already thrown them
away – or, more often, kept them and has nothing to pass them to.
Re-predicting from the final model on the same rows answers a different
and more flattering question.

`held_out()` is the way in for those. Wrap the observed outcomes and the
predictions that were made for them, and pass the result anywhere a
model would go:

    pairs <- held_out(cv$observed, cv$predicted)
    plotROC(pairs, folds = cv$fold)
    plotThreshold(pairs, folds = cv$fold)
    plotCalibration(pairs)

## What it does not do

It cannot check the predictions are out of sample. Nothing in a pair of
numeric vectors records which model made them or what it was fitted to,
so `in.sample` is taken on trust – the argument exists to be set
honestly, and defaults to `FALSE` because that is what the function is
named for.

That is a real difference from the model path, which inspects the fit
and warns when it recognises its own training data. Passing training
predictions here gets no warning, because there is nothing to notice it
with.

It also cannot support
[`plotImportance()`](https://camilleross.org/fancyfx/reference/plotImportance.md)
or
[`permutation_importance()`](https://camilleross.org/fancyfx/reference/permutation_importance.md),
which shuffle a predictor and re-predict. That needs a model by
construction, not a record of what one once said.

## See also

[`threshold_metrics()`](https://camilleross.org/fancyfx/reference/threshold_metrics.md),
[`plotROC()`](https://camilleross.org/fancyfx/reference/plotROC.md),
[`plotThreshold()`](https://camilleross.org/fancyfx/reference/plotThreshold.md),
[`plotCalibration()`](https://camilleross.org/fancyfx/reference/plotCalibration.md).

Other evaluation plots:
[`calc_deviance()`](https://camilleross.org/fancyfx/reference/calc_deviance.md),
[`calibration_estimates()`](https://camilleross.org/fancyfx/reference/calibration_estimates.md),
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
truth <- rbinom(200, 1, 0.3)
score <- plogis(rnorm(200, ifelse(truth == 1, 1, -1)))

pairs <- held_out(truth, score)
metrics <- threshold_metrics(pairs)
metrics$.threshold[which.max(metrics$.tss)]
#> [1] 0.5369681

# Fold-wise, when the predictions came from cross-validation.
folds <- rep(1:5, length.out = 200)
head(threshold_metrics(pairs, folds = folds))
#> Scoring within cross-validation folds. Cross-validated metrics are weaker evidence than a genuinely independent hold-out: the folds come from the same sample, and the model saw the rest of it. For spatial data the gap is wider still, because a held-out point usually has a near neighbour in the training folds -- use spatially blocked folds rather than random ones, and read the spread across folds as the honest part of the picture.
#>   .threshold .sensitivity .specificity       .tpr       .fpr       .tss .fold
#> 1        Inf   0.00000000    1.0000000 0.00000000 0.00000000 0.00000000     1
#> 2  0.9408823   0.09090909    1.0000000 0.09090909 0.00000000 0.09090909     1
#> 3  0.8938047   0.18181818    1.0000000 0.18181818 0.00000000 0.18181818     1
#> 4  0.8172255   0.18181818    0.9655172 0.18181818 0.03448276 0.14733542     1
#> 5  0.8061367   0.27272727    0.9655172 0.27272727 0.03448276 0.23824451     1
#> 6  0.7871747   0.27272727    0.9310345 0.27272727 0.06896552 0.20376176     1
```
