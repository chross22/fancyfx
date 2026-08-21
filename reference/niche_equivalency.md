# Test an observed overlap against a null of interchangeable occurrences

A pair of surfaces will overlap substantially whatever the species do,
simply because both were built from the same covariates over the same
domain. This asks whether the observed overlap is higher than it would
be if the two sets of occurrences were interchangeable.

## Usage

``` r
niche_equivalency(
  occurrence.x,
  occurrence.y,
  fit,
  n.rep = 99,
  statistic = c("D", "I"),
  seed = 1
)
```

## Arguments

- occurrence.x, occurrence.y:

  The two occurrence data frames the models were fitted on.

- fit:

  A function taking one occurrence data frame and returning a
  suitability surface – a `SpatRaster` or numeric vector. It is called
  once per group per replicate, so it should be cheap.

- n.rep:

  Number of randomisations.

- statistic:

  `"D"` or `"I"`.

- seed:

  Random seed.

## Value

A list with the `observed` overlap, the `null` distribution, and the
one-sided `p.value` for the observed being lower than the null.

## Details

Under the null, the two sets of occurrences are pooled and split again
at random into groups of the original sizes, and both models are
refitted. The overlap of that pair is one draw from the null
distribution. Repeated, it says how much overlap the shared covariates
and shared domain buy on their own, following Warren et al. (2008).

The observed overlap being *lower* than the null is the informative
result: it says the two groups occupy measurably different environments.
An overlap inside the null distribution means the data cannot
distinguish them, which is not the same as showing they are the same.

The test refits the model `2 * n.rep` times, so a slow `fit` makes it
slow. That cost is inherent – the null has to come from the same fitting
procedure as the observation, or it is testing something else.

## References

Warren, D. L., Glor, R. E., & Turelli, M. (2008). Environmental niche
equivalency versus conservatism: quantitative approaches to niche
evolution. *Evolution*, 62(11), 2868-2883.
[doi:10.1111/j.1558-5646.2008.00482.x](https://doi.org/10.1111/j.1558-5646.2008.00482.x)

## See also

[`niche_overlap()`](https://camilleross.org/fancyfx/reference/niche_overlap.md)
for the statistic itself.

Other spatial plots:
[`ensemble_summary()`](https://camilleross.org/fancyfx/reference/ensemble_summary.md),
[`hex_bin()`](https://camilleross.org/fancyfx/reference/hex_bin.md),
[`mess()`](https://camilleross.org/fancyfx/reference/mess.md),
[`niche_overlap()`](https://camilleross.org/fancyfx/reference/niche_overlap.md),
[`plot.fancyfx_equivalency()`](https://camilleross.org/fancyfx/reference/plot.fancyfx_equivalency.md),
[`plotExtrapolation()`](https://camilleross.org/fancyfx/reference/plotExtrapolation.md),
[`plotHexbin()`](https://camilleross.org/fancyfx/reference/plotHexbin.md),
[`plotUncertainty()`](https://camilleross.org/fancyfx/reference/plotUncertainty.md),
[`thin_points()`](https://camilleross.org/fancyfx/reference/thin_points.md)

## Examples

``` r
set.seed(1)
# Two groups occupying different parts of a covariate
a <- data.frame(temp = rnorm(60, 8, 1.5))
b <- data.frame(temp = rnorm(60, 14, 1.5))

# A toy "model": density of occurrences over a fixed grid
grid <- seq(0, 20, length.out = 50)
fit_density <- function(occurrence) {
  stats::dnorm(grid, mean(occurrence$temp), stats::sd(occurrence$temp))
}

result <- niche_equivalency(a, b, fit_density, n.rep = 19)
result$observed
#> [1] 0.02386189
result$p.value
#> [1] 0.05
```
