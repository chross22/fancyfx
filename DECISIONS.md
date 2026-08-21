# Design decisions and their justifications

Why `fancyfx` does what it does, where a different choice was available
and a reason was needed to prefer one. Written to be defensible: where a
claim is empirical, the measurement is given.

Everything here is also in the function documentation. This file gathers
it in one place so a choice can be looked up without hunting through
help pages.

**Contents**

1.  [What gets plotted](#id_1-what-gets-plotted)
2.  [Uncertainty](#id_2-uncertainty)
3.  [Model classes](#id_3-model-classes)
4.  [Evaluation](#id_4-evaluation)
5.  [Calibration](#id_5-calibration)
6.  [Variable importance](#id_6-variable-importance)
7.  [Spatial](#id_7-spatial)
8.  [Colour and type](#id_8-colour-and-type)
9.  [Dependencies and licensing](#id_9-dependencies-and-licensing)
10. [Bugs found and fixed](#id_10-bugs-found-and-fixed)

------------------------------------------------------------------------

## 1. What gets plotted

### The rug above every effect curve

The founding idea. A confident-looking bend at the end of an axis means
little if three observations sit under it, and nothing in a bare effect
curve says so. The rug puts the shape of the effect and the weight of
evidence behind it in the same figure.

Everything else in the package is an application of that principle: show
the reader what is actually supporting the claim.

### Partial effects and predictions are different quantities

| Model | Backend | Quantity |
|----|----|----|
| mgcv `gam`, `bam`, `scam`, `gamm4`, `gamm` | `gratia` | Partial effect, link scale, centered |
| everything else | `marginaleffects` | Predicted values, response scale |

A GAM partial effect is one term’s contribution in isolation, centered
so it averages to zero, with the rest of the model excluded. A
prediction is the model’s fitted output with the other predictors held
at representative values. They are not comparable, and the y-axis label
says which one you got.

**Why not force one convention.** Reporting predictions for a GAM would
discard the quantity people fit GAMs to see. Reporting partial effects
for everything would require a centered decomposition that most model
classes do not offer.

### A GAM asked for the response scale gets predictions

A centered partial effect has no coherent back-transformation.
Exponentiating a term that averages to zero produces a curve that looks
meaningful and is not. So `scale = "response"` on a GAM falls through to
the prediction backend, and the `"quantity"` attribute records the
switch so the axis label follows.

### `scale = "auto"` rather than a fixed default

A fixed `"link"` default fails outright: `marginaleffects` refuses
`type = "link"` for a Gaussian `lm`. `"auto"` resolves per backend —
`"link"` for a GAM partial effect, `"response"` for predictions — so a
bare call works for every supported class.

------------------------------------------------------------------------

## 2. Uncertainty

### The default ribbon is a 95% pointwise interval

Changed in 0.10.0. It was `±1 SE` — roughly 68% — inherited from the
package’s GAM-only origins and kept for backward compatibility.

That was the weakest default in the package, and the reason is
comparative:

|  | Ribbon | Width on one test smooth |
|----|----|----|
| `fancyfx` before 0.10.0 | ±1 SE | **0.104** (~68%) |
| [`mgcv::plot.gam()`](https://rdrr.io/pkg/mgcv/man/plot.gam.html) | ±2 SE | 0.207 (~95%) |
| [`gratia::draw()`](https://gavinsimpson.github.io/gratia/reference/draw.html) | 95% CI | 0.203 |

**Half the width of what both mgcv and gratia draw.** A reader seeing a
ribbon on a GAM smooth will assume 95%, and a caption saying otherwise
does not travel with the figure into a manuscript. That is precisely the
quiet misreading this package exists to prevent: the rug is there so
nobody over-reads a curve, and the ribbon was then under-reporting the
uncertainty by half.

Backward compatibility was a real argument and it lost, because the
package had already been renamed, its scope had widened well past GAMs,
and it had not reached 1.0. If a default was going to change, that was
the moment.

`interval = "se"` still gives the narrow band — now as an explicit
request rather than a silent default.
[`plotSmooths()`](https://camilleross.org/fancyfx/reference/plotSmooths.md),
the deprecated GAM-only ancestor, **pins `interval = "se"`**: its entire
contract is that old code keeps drawing what it always drew, so it did
not follow the change.

### Simultaneous bands for GAM smooths

A pointwise interval covers the true value at each *x* separately, with
the stated probability *at that x*. Across a curve evaluated at a
hundred points, the true function strays outside a pointwise 95% band
far more often than 5% of the time.

Any claim about the **shape** of a smooth — which is usually why one is
drawn — is a claim about the whole curve, and needs a band that covers
the whole curve.

> **Measured:** on the test fixture, mean band width 0.165 pointwise
> versus 0.301 simultaneous — **83% wider**. Point estimates and
> evaluation grid are identical; only the ribbon changes.

Simulated from the posterior of the smooth via `gratia`, so it is seeded
and the caller’s RNG stream is restored afterwards. Available for GAM
partial effects only; requesting it elsewhere is an error rather than a
silent substitution.

### Response-scale intervals are built on the link scale

A delta-method band computed directly on the response scale runs past 0
and 1 near the ends of a logistic curve — a plot claiming something a
probability cannot be. Computing on the link scale and back-transforming
keeps it inside the admissible range.

That construction is **asymmetric about the estimate**, so it has no
single standard error behind it, and `marginaleffects` returns no
`std.error` column for it. `interval = "se"` therefore cannot use it.
The documentation says to prefer `"ci"` when plotting probabilities.

### Bayesian fits get a credible interval, because they have nothing else

Posterior summaries yield an interval and **no standard error at all**.
Reading `estimate - std.error` would give a zero-length vector.
`interval = "auto"` resolves to the credible interval for a posterior
fit and to the historical SE ribbon everywhere else, so no existing plot
changes. `"cri"` is accepted as a name for the same computation.

### Boosted regression trees get no band

A boosted ensemble has no analytic standard error for its partial
dependence. Rather than invent one, the curve is drawn with none, and
the package says so once per session — pointing at bootstrapping the fit
as the honest route to an interval.

------------------------------------------------------------------------

## 3. Model classes

### Mixed models default to `re.form = NA`

**This is not cosmetic.**
[`marginaleffects::datagrid()`](https://rdrr.io/pkg/marginaleffects/man/datagrid.html)
pins the grouping factor to its modal level. Left to the backend’s own
default, the plot silently shows the effect for whichever group happens
to be most common, not the average one.

> **Measured:** on the `lme4` test fixture, mean effect 11.95 at the
> population level versus 7.99 with the grouping factor pinned — roughly
> half the range of the response.

Stated limitation: the ribbon covers uncertainty in the fixed effects
only. It does not widen for variation between groups, so it is narrower
than a genuine prediction interval for a new group.

### The random-effects argument is named per class

`brms` calls it `re_formula`; `lme4`, `glmmTMB` and `rstanarm` call it
`re.form`. Passing the wrong one to a `brmsfit` still reaches the
prediction function but makes `marginaleffects` warn on every panel, and
relies on behaviour that is not guaranteed. The name is chosen from the
class.

`rstanarm` gets warned about anyway, because `marginaleffects` keeps a
whitelist of arguments per class and `re.form` is not on it for
`stanreg` — though `rstanarm`’s own `posterior_epred()` documents it.
That warning concerns an argument name this package always supplies
itself and carries nothing the caller could act on, so it is muffled. A
genuinely unknown argument the caller passes still warns.

### `scam` needs its own method

`scam` objects inherit from `glm`, not `gam`, so without a method they
fell through to the prediction backend and **quietly reported a
different quantity than every other GAM**. `gratia` handles `scam`
perfectly well; it just never got the chance.

A test asserts that a monotone-constrained (`bs = "mpi"`) smooth comes
back monotone, which fails if the wrong backend runs.

### `gamm4` and `gamm` are unwrapped to `$gam`

They do not return fitted models. They return a *list* holding the GAM
beside the mixed-model fit it was estimated through, and
[`formula()`](https://rdrr.io/r/stats/formula.html),
[`predict()`](https://rdrr.io/r/stats/predict.html) and
`marginaleffects` all refuse the wrapper — so effect plots, predictions
and every evaluation function were unavailable.

The unwrapped fit also carries class `"gam"` alone where one from
[`mgcv::gam()`](https://rdrr.io/pkg/mgcv/man/gam.html) carries
`c("gam", "glm", "lm")`, and `marginaleffects` dispatches on the full
inheritance. **Restoring the classes** is what makes the response scale
work.

That is a real liberty to take with someone’s object, so it is tested
rather than asserted:

> **Verified:** estimates come back **identical** to calling
> `predict(se.fit = TRUE)` on the original; standard errors agree to
> about **1e-7 relative** — `marginaleffects` differentiates numerically
> for the delta method, so the last digits differ.

The random effects stay behind with the wrapper, so the smooth is drawn
at the population level — consistent with how mixed models are treated
throughout.

------------------------------------------------------------------------

## 4. Evaluation

### `newdata` is required, with no default

A model scored against the data it was fitted to flatters itself,
sometimes enormously, and an in-sample ROC curve can look excellent for
a model with no predictive value at all. Making that the easiest figure
to produce would be a disservice.

Passing the training data still works — refusing outright would be
obstructive, and sometimes it is genuinely what you want — but it
**warns**, and every figure built from it is captioned as in-sample so
it cannot quietly be published as validation.

Detection compares `newdata` against the model’s own
[`model.frame()`](https://rdrr.io/r/stats/model.frame.html). When the
model does not expose one, the answer is `NA` and nothing is claimed.

### Cross-validation is noted as weaker evidence

Using `folds` emits a note, once per session:

- CV folds come from the same sample the model was fitted on, so a
  cross-validated score speaks to how **stable** the fit is, not how it
  will behave somewhere new.
- For spatial data the gap is wider: with random folds a held-out point
  usually has a near neighbour among the training folds, so the model
  has in effect already seen it.

[`spatial_sorting_bias()`](https://camilleross.org/fancyfx/reference/spatial_sorting_bias.md)
exists to put a number on that second point rather than leaving it as a
warning. Fold-wise metrics are drawn **per fold** rather than averaged,
because the spread is the informative part.

### AUC is computed from ranks, not by integrating the curve

The rank form is the Mann-Whitney U statistic, which handles tied
predictions exactly by giving them mid-ranks. Trapezoidal integration
over a curve with ties gives a slightly different answer depending on
how the ties were ordered.

> **Verified against an independent implementation:** agrees with
> [`yardstick::roc_auc_vec()`](https://yardstick.tidymodels.org/reference/roc_auc.html)
> to floating point. The test checks against `yardstick`, not against a
> number this package produced.

### The ROC is drawn as a step function

An empirical ROC *is* a step function. Joining the corners with straight
lines draws operating points the model cannot actually reach.

### Metrics are refused where they are meaningless

AUC and TSS are defined for a binary outcome and nothing else. Applied
to a Gaussian model of biomass they would return a number with no
meaning, so a non-binary response is **refused with an error naming the
offending values** rather than scored.

### `held_out()` for predictions you already have

Under k-fold CV the honest predictions live across *k* models, none of
which is the final fit. Re-predicting from the final model on the same
rows answers a different and more flattering question.
[`held_out()`](https://camilleross.org/fancyfx/reference/held_out.md)
accepts the stored pairs instead.

Two limits, stated rather than hidden:

- It **cannot verify** the predictions are out of sample. Nothing in a
  pair of numeric vectors records which model made them, so `in.sample`
  is taken on trust — unlike the model path, which inspects the fit.
- It **cannot support**
  [`plotImportance()`](https://camilleross.org/fancyfx/reference/plotImportance.md),
  which shuffles a predictor and re-predicts. That needs a model by
  construction.

------------------------------------------------------------------------

## 5. Calibration

### Why it gets its own plot

Calibration is a different property from discrimination, and **AUC is
structurally blind to it**. AUC only cares about ranking, so it is
unchanged by any monotone rescaling of the predictions. A model can post
an excellent AUC while every probability it reports is far too extreme.

> **Demonstrated in the tests:** inflating a fitted model’s coefficients
> leaves AUC **identical to the digit** while the calibration slope
> falls from **0.91 to 0.36**.

This matters because these probabilities rarely stay probabilities. They
get thresholded, summed into an area of suitable habitat, or turned into
an expected count — and all of those inherit miscalibration that AUC
declined to mention.

### Wilson intervals, not normal approximations

With few observations in a bin, or an observed frequency near 0 or 1 —
both routine in calibration — the normal approximation puts the interval
bounds **outside \[0, 1\]**. That would be a plot making a claim a
probability cannot make. The Wilson score interval stays in range.

### Quantile binning by default

Equal-width bins leave the extremes nearly empty, which is exactly where
miscalibration shows up — so the noisiest points land on the most
interesting behaviour. Quantile bins give every point the same number of
observations behind it. Both are available; the rug shows which regime
you are in.

### The rug, again

Calibration is usually worst at the extremes, and the extremes usually
hold the fewest predictions, so the most eye-catching departures from
the diagonal are often the least trustworthy points on the plot. The rug
of predicted probabilities and the interval on each bin both say so.

------------------------------------------------------------------------

## 6. Variable importance

### Permutation, because it is model-agnostic

It needs nothing from the model but the ability to predict, so a GAM, a
GLM, a mixed model and a Bayesian fit all give numbers that mean the
same thing and can be compared. mgcv has no native importance measure.

### Seeded, and the RNG stream restored

Permutation is random, and an unseeded figure cannot be redrawn. The
caller’s `.Random.seed` is saved and restored, because silently
resetting it would change results elsewhere in their script for reasons
they would struggle to trace.

### The spread is drawn, not just the mean

A variable whose importance swings between permutations has not been
shown to matter, and a bar chart of means hides that. The point sits at
the mean, the line spans the permutations, and the dashed zero line
marks “shuffling this did no measurable work”.

### Two limitations, documented rather than buried

- **Correlated predictors split credit badly.** If two variables carry
  much the same information, permuting either alone barely hurts,
  because the other still carries it. Both look unimportant and the pair
  is not. This bites hard on environmental covariates, which are
  routinely collinear.
- **It measures use, not effect size.** A variable can be important here
  and have an effect too small to matter, or the reverse. Read it beside
  [`plotEffects()`](https://camilleross.org/fancyfx/reference/plotEffects.md),
  not instead of it.

------------------------------------------------------------------------

## 7. Spatial

### `na.rm = FALSE` in `ensemble_summary()`

The opposite of most R summaries, deliberately. If one member is missing
over part of the domain, summarising the members that remain reports a
**narrower** uncertainty exactly where the ensemble is least complete,
and nothing on the map would say so. Leaving those cells blank makes the
gap visible.

### A coefficient of variation about zero is `NA`, not `Inf`

Otherwise the map is dominated by cells where the members happened to
average out, which is not the same as cells where they disagreed wildly.

### Aggregation is announced

Projection rasters run to millions of cells and drawing one per pixel is
pointless at figure size. Above `max.cells` the raster is aggregated —
and the plot says so in its subtitle, because silently changing what is
on the page misrepresents the map.

### MESS diverges about zero

Zero is a real boundary, not a midpoint of convenience: on one side the
model interpolates, on the other it extrapolates. A sequential scale
would hide that edge in a smooth ramp.

**Stated limitation:** MESS works one covariate at a time. A cell can be
perfectly ordinary on every axis separately and still be somewhere the
model has never been — warm *and* deep, when the survey saw warm-shallow
and cold-deep but never both. Treat a clean surface as the absence of
one specific problem, not permission to project.

### Hexagons rather than squares

Every neighbour of a hexagon shares an edge and lies the same distance
away, where a square grid has neighbours at two different distances
depending on whether they meet at an edge or a corner. That makes
hexagons better behaved for anything depending on adjacency, and removes
the visual grain a square lattice imposes.

The lattice uses axial coordinates with cube rounding, with a testable
invariant: **every point lands in the hexagon whose centre is nearest to
it**, and no point is further from its centre than the circumradius. The
test verifies this by brute force against all realised centres.

**Stated limitation:** binning unprojected longitude and latitude does
not give equal-area hexagons, because a degree of longitude shortens
toward the poles. A count per hexagon is then not a density. Noted once
per session.

### Thinning is offered with a warning about when not to use it

[`thin_points()`](https://camilleross.org/fancyfx/reference/thin_points.md)
throws data away. That is right when the clustering is an artefact of
where people looked and wrong when the clustering is the signal, and
**nothing in the function can tell those apart** — so the documentation
says so rather than implying the default is safe.

### Niche overlap is not a test

Two surfaces built from the same covariates over the same domain will
overlap substantially whatever the species do, so a D of 0.7 means
little on its own.
[`niche_equivalency()`](https://camilleross.org/fancyfx/reference/niche_equivalency.md)
supplies the reference distribution by pooling occurrences, splitting at
random, and refitting.

Its p-value counts the observation itself, so it cannot fall below
`1 / (n.rep + 1)` — reporting less would be precision the test does not
have.

------------------------------------------------------------------------

## 8. Colour and type

### The categorical palette was derived by search, not chosen by eye

The obvious candidate, **Okabe-Ito, fails** — checked, not assumed:

> Its yellow `#F0E442` sits at lightness **0.902** against a 0.77
> ceiling, with **1.29:1** contrast on white. A yellow line on a white
> panel genuinely is hard to see.

Naively darkening it collapsed the two blues to ΔE **0.4** —
indistinguishable — because Okabe-Ito separates those by lightness,
which the band forbids. So the palette was found by searching OKLCH
space under a hue-spread constraint.

Result: blue, gold, green, purple, red, teal. All six sit in the mid
lightness band, clear 3:1 contrast on white, and stay separable under
simulated protanopia and deuteranopia.

**Honest caveat:** the 5th–6th pair sits at ΔE **7.5**, above the 6.0
floor but below the 8.0 target. That is acceptable *only* because a
legend always ships, so colour never carries identity alone. With four
or fewer curves the worst pair is **17.9**.

Past six colours the palette refuses to invent a hue and says to facet,
because recycling would label two levels identically.

### Sequential for magnitude, diverging for polarity

Uncertainty is a magnitude, so it gets a perceptually uniform viridis
ramp. A rainbow invents boundaries where the data has none — which on an
uncertainty map means inventing places the ensemble agreed.

### The ribbon is drawn under the line

At alpha 0.5 on top, the ribbon washes out the curve it belongs to. This
was the behaviour before
[`plotEffects()`](https://camilleross.org/fancyfx/reference/plotEffects.md);
drawing order is now asserted in a test.

### Font sizes scale together, or individually

`base_size` scales every text element proportionally and keeps them
balanced. Each element also takes its own argument for when that is not
enough. Panel labels and the figure title are drawn by
`ggarrange`/`annotate_figure` rather than by the theme, so they need
`label.size` and `title.size` — without which raising `base_size` leaves
them stranded at their defaults.

------------------------------------------------------------------------

## 9. Dependencies and licensing

### Heavy dependencies are `Suggests`, not `Imports`

`terra`, `gbm`, `brms`, `rstanarm`, `lme4`, `glmmTMB`, `scam`, `gamm4`.
Someone plotting a GLM should not have to install a geospatial or Stan
stack. The functions that need them check and say what to run.

`collapse` is a `Suggests` too: `marginaleffects` needs it for posterior
draws but does not itself require it, so brms support fails without it.

### Some things are hand-rolled to avoid a dependency

The hexagonal lattice, MESS, the haversine distance, the Wilson
interval, the once-per-session notice machinery. Each is short, each has
a testable property, and each would otherwise pull in a package for a
few lines of arithmetic.

### dismo is GPL-3; this package is MIT

Four functions descend from dismo, which was superseded by `predicts`
and left them behind:
[`spatial_sorting_bias()`](https://camilleross.org/fancyfx/reference/spatial_sorting_bias.md),
[`thin_points()`](https://camilleross.org/fancyfx/reference/thin_points.md),
[`niche_overlap()`](https://camilleross.org/fancyfx/reference/niche_overlap.md)
and
[`niche_equivalency()`](https://camilleross.org/fancyfx/reference/niche_equivalency.md).

**All four are written from their published definitions** — Hijmans
(2012), Warren et al. (2008) — **not from dismo’s source.** Copying
GPL-3 code into an MIT package would be a licence violation.
Implementing a published algorithm and citing it is ordinary scholarly
practice; algorithms are not copyrightable, specific code is.

Every borrowed method carries its citation on the function that
implements it:

| Function | Source |
|----|----|
| [`mess()`](https://camilleross.org/fancyfx/reference/mess.md), [`plotExtrapolation()`](https://camilleross.org/fancyfx/reference/plotExtrapolation.md) | Elith, Kearney & Phillips 2010 |
| [`spatial_sorting_bias()`](https://camilleross.org/fancyfx/reference/spatial_sorting_bias.md) | Hijmans 2012 |
| [`niche_overlap()`](https://camilleross.org/fancyfx/reference/niche_overlap.md), [`niche_equivalency()`](https://camilleross.org/fancyfx/reference/niche_equivalency.md) | Warren, Glor & Turelli 2008 |
| [`plotROC()`](https://camilleross.org/fancyfx/reference/plotROC.md), [`threshold_metrics()`](https://camilleross.org/fancyfx/reference/threshold_metrics.md) | Allouche, Tsoar & Kadmon 2006 |
| [`permutation_importance()`](https://camilleross.org/fancyfx/reference/permutation_importance.md) | Breiman 2001 |
| [`calc_deviance()`](https://camilleross.org/fancyfx/reference/calc_deviance.md) | Elith, Leathwick & Hastie 2008 |
| [`calibration_estimates()`](https://camilleross.org/fancyfx/reference/calibration_estimates.md) | Harrell 2015 |
| [`plotEffects()`](https://camilleross.org/fancyfx/reference/plotEffects.md) | Wood 2017 |

The diverging map poles `#B2182B` and `#2166AC` are ColorBrewer *RdBu*
values (Cynthia Brewer, Apache-2.0).

[`calc_deviance()`](https://camilleross.org/fancyfx/reference/calc_deviance.md)
is checked against `glm`’s own deviance for the binomial, poisson and
gaussian families — it agrees exactly.

------------------------------------------------------------------------

## 10. Bugs found and fixed

Recorded because they are the kind of thing that recurs, and because two
of them predate this package’s current name.

### Factor smooths drawn as one zigzag

`s(x, by = f)` is one smooth per level, and `gratia` returns them
stacked. Drawn as a single series, `geom_line()` joined the end of each
level’s curve to the start of the next — a 300-row frame rendered as one
wildly varying curve. Estimates now carry a `.group` column, sorted
within group, mapped to colour.

**Predates the rename.** The old DESCRIPTION advertised factor-smooth
plotting as a feature.

### A variable name that prefixes another matched both

`gratia`’s `partial_match` is *substring* matching, so asking for the
effect of `x1` in a model that also smooths `x11` returned **both
smooths concatenated** — the same failure as above, from a different
cause. Smooth labels are now matched on a word boundary, which keeps
every level of a factor-smooth while refusing the prefix collision.

**Predates the rename.**

### The folds length check could never fire

It compared lengths *after* subsetting for missingness, by which point a
short vector had been NA-padded to the right length. The mismatch
surfaced later as “no fold contains both classes”. Now validated against
`nrow(newdata)` up front.

### The density rug was a bare outline

`geom_density()` takes no fill unless told, and `alpha` does nothing to
an unfilled shape — so the density rug read as far lighter than the
histogram it substitutes for.

### A GAM’s effect was evaluated at its data, not on a grid

[`plotEffects()`](https://camilleross.org/fancyfx/reference/plotEffects.md)
takes the raw data as its second argument, for the rug. That argument
was also forwarded to
[`gratia::smooth_estimates()`](https://gavinsimpson.github.io/gratia/reference/smooth_estimates.html)
as `data =`, which is not where the range comes from – it is where the
smooth is *evaluated*. So every GAM curve this package drew was
evaluated at every observed row rather than at the `n` points asked for,
and `n` had no effect on a GAM at all. On a model fitted to 8,622
segments that is a polyline through 8,622 points where a hundred were
requested.

`data` is documented as the fall-back for models that do not keep what
they were fitted on – a `gbm` – and a GAM always keeps its model frame,
so it is now dropped before the call and `n` is passed instead.

### A smooth of a transformed term could not be drawn at all

`s(log10(depth))` is an ordinary thing to fit and it failed three ways
at once. `gratia` handled the term correctly on its own but not through
the `data =` path above, where it looked for a column literally named
`log10(depth)`. The word-boundary filter on smooth labels built its
pattern by pasting the term into a regex, so the parentheses became a
capture group and the pattern searched for `log10depth` – reporting a
smooth as absent that `gratia` had just returned. And `\b` cannot hold
after a closing parenthesis anyway, since the next character inside
`s(log10(depth))` is another one. The term is now escaped and the
boundaries are applied only at edges that are word characters, which is
the case they were protecting.

The rug had the same shape of problem from the other end: `.data[[var]]`
can only look a column up. The term is now evaluated in the data – in
the data frame alone, with no enclosing environment, so a term naming a
column that is absent cannot silently pick up a variable of the same
name from the caller and draw a rug of something else.

Found while plotting a density surface fitted with `s(log10(DEPTH))`.

### `combinePlots()` hardcoded “Partial Effect”

Which would be wrong for every model reporting predictions.

------------------------------------------------------------------------

*Every claim marked **measured** or **verified** has a corresponding
test in `tests/testthat/`.*
