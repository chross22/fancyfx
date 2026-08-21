# Package index

## Effect plots

Every effect curve is paired with a rug of the raw data stacked directly
above it, so a bend can be read against how much data supports it. GAMs
go through gratia, everything else through marginaleffects.

- [`effect_estimates()`](https://camilleross.org/fancyfx/reference/effect_estimates.md)
  : Extract a variable's effect from a model as a tidy data frame
- [`permutation_importance()`](https://camilleross.org/fancyfx/reference/permutation_importance.md)
  : Permutation importance for a fitted model
- [`plotEffects()`](https://camilleross.org/fancyfx/reference/plotEffects.md)
  : Plot a predictor's effect with a rug of the raw data above it
- [`plotImportance()`](https://camilleross.org/fancyfx/reference/plotImportance.md)
  : Plot permutation importance
- [`plotRugs()`](https://camilleross.org/fancyfx/reference/plotRugs.md)
  : Create rug plots representing distribution of the raw data
- [`plotSmooths()`](https://camilleross.org/fancyfx/reference/plotSmooths.md)
  : Extract and plot smooths from a GAM (deprecated)

## Performance and calibration

Whether the model is right, and whether its probabilities mean what they
say.

- [`calc_deviance()`](https://camilleross.org/fancyfx/reference/calc_deviance.md)
  : Deviance of a set of predictions
- [`calibration_estimates()`](https://camilleross.org/fancyfx/reference/calibration_estimates.md)
  : Are the model's predicted probabilities honest?
- [`held_out()`](https://camilleross.org/fancyfx/reference/held_out.md)
  : Evaluate predictions you already have
- [`plotCalibration()`](https://camilleross.org/fancyfx/reference/plotCalibration.md)
  : Plot a calibration curve with a rug of where predictions fall
- [`plotROC()`](https://camilleross.org/fancyfx/reference/plotROC.md) :
  Plot a ROC curve
- [`plotThreshold()`](https://camilleross.org/fancyfx/reference/plotThreshold.md)
  : Plot classification metrics against the decision threshold
- [`print(`*`<fancyfx_held_out>`*`)`](https://camilleross.org/fancyfx/reference/print.fancyfx_held_out.md)
  : Print a held_out object
- [`threshold_metrics()`](https://camilleross.org/fancyfx/reference/threshold_metrics.md)
  : Threshold-dependent classification metrics across every cutoff

## Extrapolation and novelty

Where a prediction is being made outside the data it was fitted on. MESS
and the sorting-bias measures say how far outside.

- [`ensemble_summary()`](https://camilleross.org/fancyfx/reference/ensemble_summary.md)
  : Summarise an ensemble of projection rasters
- [`mess()`](https://camilleross.org/fancyfx/reference/mess.md) :
  Multivariate environmental similarity surface
- [`niche_equivalency()`](https://camilleross.org/fancyfx/reference/niche_equivalency.md)
  : Test an observed overlap against a null of interchangeable
  occurrences
- [`niche_overlap()`](https://camilleross.org/fancyfx/reference/niche_overlap.md)
  : How much do two predicted distributions overlap?
- [`plot(`*`<fancyfx_equivalency>`*`)`](https://camilleross.org/fancyfx/reference/plot.fancyfx_equivalency.md)
  : Plot a niche equivalency test against its null
- [`plotExtrapolation()`](https://camilleross.org/fancyfx/reference/plotExtrapolation.md)
  : Map where a projection leaves the conditions the model was fitted
  under
- [`plotUncertainty()`](https://camilleross.org/fancyfx/reference/plotUncertainty.md)
  : Map the disagreement between ensemble members
- [`spatial_sorting_bias()`](https://camilleross.org/fancyfx/reference/spatial_sorting_bias.md)
  : Spatial sorting bias in a train/test split

## Composition and style

Arranging panels, binning dense scatter, and the palette and theme that
keep a set of figures looking like one set.

- [`combinePlots()`](https://camilleross.org/fancyfx/reference/combinePlots.md)
  : Combine multiple effect plots for simultaneous display
- [`comparePlots()`](https://camilleross.org/fancyfx/reference/comparePlots.md)
  : Compare the same effect across several models
- [`fancyfx_palette()`](https://camilleross.org/fancyfx/reference/fancyfx_palette.md)
  : Colours for effects split into several curves
- [`hex_bin()`](https://camilleross.org/fancyfx/reference/hex_bin.md) :
  Aggregate spatial values into hexagonal bins
- [`plotHexbin()`](https://camilleross.org/fancyfx/reference/plotHexbin.md)
  : Map values aggregated into hexagonal bins
- [`theme_fancyfx()`](https://camilleross.org/fancyfx/reference/theme_fancyfx.md)
  : A publication-ready theme for effect plots
- [`thin_points()`](https://camilleross.org/fancyfx/reference/thin_points.md)
  : Thin points so that no cell holds more than a few
