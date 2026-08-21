# fancyfx: Publication-Ready Effect and Evaluation Plots for Models

An effect curve on its own is easy to over-read. A confident-looking
bend at the far end of the x axis means very little if only three
observations sit under it. `fancyfx` addresses that by pairing every
effect curve with a rug of the raw data, drawn directly above it on a
shared x axis, so the shape of the effect and the weight of evidence
behind it are read together.

## Details

The second thing it is for is getting that figure into a manuscript
without a further round of fiddling. Defaults are chosen for publication
rather than for exploration, so the plot you get from a bare call is
close to the plot you would submit.

## Effect plots

- [`plotEffects()`](https://camilleross.org/fancyfx/reference/plotEffects.md):

  One predictor: the effect curve with its rug above.

- [`combinePlots()`](https://camilleross.org/fancyfx/reference/combinePlots.md):

  Several predictors, arranged and labelled as panels.

- [`comparePlots()`](https://camilleross.org/fancyfx/reference/comparePlots.md):

  Several competing models, side by side.

- [`plotRugs()`](https://camilleross.org/fancyfx/reference/plotRugs.md):

  The rug on its own, if you want to compose it yourself.

- [`effect_estimates()`](https://camilleross.org/fancyfx/reference/effect_estimates.md):

  The tidy numbers behind any of the above.

## Evaluation plots

Effect plots say what a model claims; these ask whether it has earned
the claim. They are for presence/absence models, since AUC and TSS are
defined for a binary outcome and nothing else.

- [`plotROC()`](https://camilleross.org/fancyfx/reference/plotROC.md):

  Discrimination: sensitivity against the false positive rate, with AUC.

- [`plotThreshold()`](https://camilleross.org/fancyfx/reference/plotThreshold.md):

  Where to cut: sensitivity, specificity and TSS across every threshold.

- [`plotCalibration()`](https://camilleross.org/fancyfx/reference/plotCalibration.md):

  Whether the predicted probabilities are honest – a separate question
  from discrimination, which AUC cannot answer.

- [`plotImportance()`](https://camilleross.org/fancyfx/reference/plotImportance.md):

  Which predictors the model is leaning on, by permutation.

- [`threshold_metrics()`](https://camilleross.org/fancyfx/reference/threshold_metrics.md),
  [`calibration_estimates()`](https://camilleross.org/fancyfx/reference/calibration_estimates.md),
  [`permutation_importance()`](https://camilleross.org/fancyfx/reference/permutation_importance.md):

  The tidy numbers behind those.

Every one of these requires evaluation data explicitly. Scoring a model
on the data it was fitted to flatters it, so that path warns and
annotates the figure rather than being the quiet default. See
[`vignette("evaluation")`](https://camilleross.org/fancyfx/articles/evaluation.md).

## Spatial projections

For models projected onto a raster, two maps that answer questions a
projection map on its own cannot. terra is a suggested package rather
than a required one, so nothing here is installed for users who never
project.

- [`plotUncertainty()`](https://camilleross.org/fancyfx/reference/plotUncertainty.md):

  Where the members of an ensemble disagree.

- [`plotExtrapolation()`](https://camilleross.org/fancyfx/reference/plotExtrapolation.md):

  Where the projection leaves the range of conditions the model was
  fitted under, and is therefore guessing.

- [`hex_bin()`](https://camilleross.org/fancyfx/reference/hex_bin.md),
  [`plotHexbin()`](https://camilleross.org/fancyfx/reference/plotHexbin.md):

  Aggregate a raster or point data into a hexagonal lattice.

- [`thin_points()`](https://camilleross.org/fancyfx/reference/thin_points.md):

  Thin records so that no cell holds more than a few, where clustering
  reflects survey effort rather than the species.

- [`niche_overlap()`](https://camilleross.org/fancyfx/reference/niche_overlap.md),
  [`niche_equivalency()`](https://camilleross.org/fancyfx/reference/niche_equivalency.md):

  How much two predicted distributions overlap, and whether that is more
  than chance.

- [`ensemble_summary()`](https://camilleross.org/fancyfx/reference/ensemble_summary.md),
  [`mess()`](https://camilleross.org/fancyfx/reference/mess.md):

  The rasters behind those.

See
[`vignette("spatial")`](https://camilleross.org/fancyfx/articles/spatial.md).

## Diagnostics for spatial validation

[`spatial_sorting_bias()`](https://camilleross.org/fancyfx/reference/spatial_sorting_bias.md)
measures how independent a train/test split really is – whether the test
presences sit closer to the training data than the test absences do,
letting a model score well on proximity alone. It is the quantity behind
this package's warnings about random cross-validation folds on spatially
correlated data: those say the problem exists, this says how bad it is
for a particular split.

## Publication-ready by default

[`theme_fancyfx()`](https://camilleross.org/fancyfx/reference/theme_fancyfx.md)
is built on
[`ggpubr::theme_pubr()`](https://rpkgs.datanovia.com/ggpubr/reference/theme_pubr.html):
no background panel, no grid, plain black axis lines, and text sized to
survive being shrunk into a journal column. Panels are lettered `A`,
`B`, `C`, with the style selectable for whatever a journal asks for.

Effects split by a factor are coloured with
[`fancyfx_palette()`](https://camilleross.org/fancyfx/reference/fancyfx_palette.md),
chosen by search rather than by eye: every colour sits in a mid
lightness band, clears a 3:1 contrast ratio against a white page, and
stays separable under simulated protanopia and deuteranopia. A legend is
always drawn, so identity never rests on colour alone.

Every one of these is an argument, so a house style can replace any of
them.

## Supported models

Generalized additive models are handled by
[`gratia::smooth_estimates()`](https://gavinsimpson.github.io/gratia/reference/smooth_estimates.html),
which reports the *partial effect* of a smooth on the link scale. That
covers mgcv's `gam()` and `bam()`, the shape-constrained `scam()`, and
`gamm4()` and `gamm()` – the last two being lists that hold a GAM rather
than fitted models, which are unwrapped to their `$gam` so every other
part of the package can use them. Every other model class is handled by
[`marginaleffects::predictions()`](https://rdrr.io/pkg/marginaleffects/man/predictions.html),
which reports *predicted values* with the remaining predictors held at
representative values – this covers `lm`, `glm`, mixed models from lme4
and glmmTMB, and Bayesian fits from brms and rstanarm, among many
others.

These are different quantities, and `fancyfx` does not pretend
otherwise: the y-axis label changes to say which one you are looking at.
See the `scale` argument of
[`plotEffects()`](https://camilleross.org/fancyfx/reference/plotEffects.md),
and the "What the y axis means" section of
[`vignette("fancyfx")`](https://camilleross.org/fancyfx/articles/fancyfx.md).

## References

Wood, S. N. (2017). *Generalized Additive Models: An Introduction with
R* (2nd ed.). Chapman and Hall/CRC.
[doi:10.1201/9781315370279](https://doi.org/10.1201/9781315370279)

Arel-Bundock, V., Greifer, N., & Heiss, A. (2024). How to interpret
statistical models using marginaleffects for R and Python. *Journal of
Statistical Software*, 111(9), 1-32.
[doi:10.18637/jss.v111.i09](https://doi.org/10.18637/jss.v111.i09)

## See also

Useful links:

- <https://github.com/chross22/fancyfx>

- <https://camilleross.org/fancyfx/>

- Report bugs at <https://github.com/chross22/fancyfx/issues>

## Author

**Maintainer**: Camille Ross <camille.ross@maine.edu>
([ORCID](https://orcid.org/0000-0002-1428-2294))

Authors:

- Camille Ross <camille.ross@maine.edu>
  ([ORCID](https://orcid.org/0000-0002-1428-2294))
