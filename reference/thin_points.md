# Thin points so that no cell holds more than a few

Reduces the effect of uneven survey effort. Where records pile up
because somewhere was visited often rather than because the species is
common there, a model fitted to the raw points learns the sampling as
though it were the species.

## Usage

``` r
thin_points(
  x,
  coords = NULL,
  n = 1,
  cellsize = NULL,
  bins = 20,
  type = c("hex", "grid"),
  seed = 1
)
```

## Arguments

- x:

  A data frame of points.

- coords:

  The two coordinate columns. Guessed when omitted.

- n:

  Maximum number of points to keep per cell.

- cellsize:

  Cell size in the units of the coordinates. Ignored when `bins` is
  used.

- bins:

  Approximate number of cells across the x range, as an alternative to
  naming a `cellsize`.

- type:

  `"hex"` for a hexagonal lattice, or `"grid"` for a square one.

- seed:

  Random seed, since which points survive is a random choice among those
  sharing a cell.

## Value

The rows of `x` that survive thinning, in their original order.

## Details

Thinning is a blunt instrument and it throws data away. It is worth
doing when the clustering is an artefact of where people looked, and
worth *not* doing when the clustering is the signal – there is no way
for the function to tell which, so the judgement stays with you.

The hexagonal lattice is the default for the same reason
[`hex_bin()`](https://camilleross.org/fancyfx/reference/hex_bin.md) uses
one: its cells have neighbours all at equal distance, where a square
grid does not, so thinning is not subtly directional.

## See also

[`hex_bin()`](https://camilleross.org/fancyfx/reference/hex_bin.md),
which uses the same lattice to summarise rather than to thin, and
[`spatial_sorting_bias()`](https://camilleross.org/fancyfx/reference/spatial_sorting_bias.md)
for the related problem in a train/test split.

Other spatial plots:
[`ensemble_summary()`](https://camilleross.org/fancyfx/reference/ensemble_summary.md),
[`hex_bin()`](https://camilleross.org/fancyfx/reference/hex_bin.md),
[`mess()`](https://camilleross.org/fancyfx/reference/mess.md),
[`niche_equivalency()`](https://camilleross.org/fancyfx/reference/niche_equivalency.md),
[`niche_overlap()`](https://camilleross.org/fancyfx/reference/niche_overlap.md),
[`plot.fancyfx_equivalency()`](https://camilleross.org/fancyfx/reference/plot.fancyfx_equivalency.md),
[`plotExtrapolation()`](https://camilleross.org/fancyfx/reference/plotExtrapolation.md),
[`plotHexbin()`](https://camilleross.org/fancyfx/reference/plotHexbin.md),
[`plotUncertainty()`](https://camilleross.org/fancyfx/reference/plotUncertainty.md)

## Examples

``` r
set.seed(1)
# Heavily oversampled in one corner
records <- data.frame(
  x = c(runif(400, 0, 2), runif(100, 0, 10)),
  y = c(runif(400, 0, 2), runif(100, 0, 10))
)

nrow(records)
#> [1] 500
nrow(thin_points(records, n = 1, bins = 10))
#> [1] 80
```
