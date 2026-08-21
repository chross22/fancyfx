# How much do two predicted distributions overlap?

Compares two suitability surfaces cell by cell and reports how similar
they are. Used to ask whether two species, two seasons, or the same
species under two climate scenarios occupy the same space.

## Usage

``` r
niche_overlap(x, y, statistic = c("both", "D", "I"), na.rm = FALSE)
```

## Arguments

- x, y:

  Two `SpatRaster` layers of predicted suitability, or two numeric
  vectors of equal length. Must line up cell for cell.

- statistic:

  `"D"` for Schoener's D, `"I"` for Warren's I, or `"both"`.

- na.rm:

  Whether to drop cells missing from either surface. See Details.

## Value

A named numeric vector.

## Details

Both statistics run from 0 (no overlap) to 1 (identical), and both begin
by rescaling each surface to sum to 1, so what is compared is the
*shape* of each distribution rather than its level. A model predicting
uniformly higher suitability than another can still overlap it
perfectly.

Schoener's D is one minus half the summed absolute difference. Warren's
I works on square roots, which makes it less sensitive to a handful of
cells where the two surfaces disagree sharply. They usually agree; where
they do not, D is being moved by a few strong disagreements and I by the
broad pattern.

`na.rm` defaults to `FALSE` for the same reason
[`ensemble_summary()`](https://camilleross.org/fancyfx/reference/ensemble_summary.md)
does. Dropping cells missing from one surface compares the two over a
domain neither was asked about, and nothing in the resulting number says
how much was discarded. Make the coverage match first, deliberately.

Neither statistic is a test. A D of 0.7 is not evidence of anything on
its own – two surfaces built from the same covariates over the same
domain will overlap substantially whatever the species do.
[`niche_equivalency()`](https://camilleross.org/fancyfx/reference/niche_equivalency.md)
is the randomisation test that gives it a reference distribution.

## References

Warren, D. L., Glor, R. E., & Turelli, M. (2008). Environmental niche
equivalency versus conservatism: quantitative approaches to niche
evolution. *Evolution*, 62(11), 2868-2883.
[doi:10.1111/j.1558-5646.2008.00482.x](https://doi.org/10.1111/j.1558-5646.2008.00482.x)

## See also

[`niche_equivalency()`](https://camilleross.org/fancyfx/reference/niche_equivalency.md)
to test it against a null,
[`plotUncertainty()`](https://camilleross.org/fancyfx/reference/plotUncertainty.md)
for ensemble spread.

Other spatial plots:
[`ensemble_summary()`](https://camilleross.org/fancyfx/reference/ensemble_summary.md),
[`hex_bin()`](https://camilleross.org/fancyfx/reference/hex_bin.md),
[`mess()`](https://camilleross.org/fancyfx/reference/mess.md),
[`niche_equivalency()`](https://camilleross.org/fancyfx/reference/niche_equivalency.md),
[`plot.fancyfx_equivalency()`](https://camilleross.org/fancyfx/reference/plot.fancyfx_equivalency.md),
[`plotExtrapolation()`](https://camilleross.org/fancyfx/reference/plotExtrapolation.md),
[`plotHexbin()`](https://camilleross.org/fancyfx/reference/plotHexbin.md),
[`plotUncertainty()`](https://camilleross.org/fancyfx/reference/plotUncertainty.md),
[`thin_points()`](https://camilleross.org/fancyfx/reference/thin_points.md)

## Examples

``` r
set.seed(1)
a <- runif(400)
b <- a * 0.8 + runif(400) * 0.2

niche_overlap(a, b)
#>         D         I 
#> 0.9334834 0.9948262 
niche_overlap(a, a)          # identical surfaces
#> D I 
#> 1 1 
```
