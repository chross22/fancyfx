# Plot a niche equivalency test against its null

The observed overlap on its own says little – two surfaces built from
the same covariates over the same domain overlap substantially whatever
the species do. What makes it readable is seeing it against the
distribution of overlaps that interchangeable occurrences would have
produced.

## Usage

``` r
# S3 method for class 'fancyfx_equivalency'
plot(
  x,
  title = "",
  bins = 20,
  theme = theme_fancyfx(),
  colour = fancyfx_palette(1),
  ...
)
```

## Arguments

- x:

  A result from
  [`niche_equivalency()`](https://camilleross.org/fancyfx/reference/niche_equivalency.md).

- title:

  Plot title, optional.

- bins:

  Number of histogram bins for the null distribution.

- theme:

  A ggplot2 theme. Defaults to
  [`theme_fancyfx()`](https://camilleross.org/fancyfx/reference/theme_fancyfx.md).

- colour:

  Colour of the observed-value line.

- ...:

  Ignored.

## Value

A ggplot2 object.

## See also

[`niche_equivalency()`](https://camilleross.org/fancyfx/reference/niche_equivalency.md)
for the test itself.

Other spatial plots:
[`ensemble_summary()`](https://camilleross.org/fancyfx/reference/ensemble_summary.md),
[`hex_bin()`](https://camilleross.org/fancyfx/reference/hex_bin.md),
[`mess()`](https://camilleross.org/fancyfx/reference/mess.md),
[`niche_equivalency()`](https://camilleross.org/fancyfx/reference/niche_equivalency.md),
[`niche_overlap()`](https://camilleross.org/fancyfx/reference/niche_overlap.md),
[`plotExtrapolation()`](https://camilleross.org/fancyfx/reference/plotExtrapolation.md),
[`plotHexbin()`](https://camilleross.org/fancyfx/reference/plotHexbin.md),
[`plotUncertainty()`](https://camilleross.org/fancyfx/reference/plotUncertainty.md),
[`thin_points()`](https://camilleross.org/fancyfx/reference/thin_points.md)

## Examples

``` r
set.seed(1)
grid <- seq(0, 20, length.out = 50)
fit_density <- function(o) stats::dnorm(grid, mean(o$temp), stats::sd(o$temp))

result <- niche_equivalency(data.frame(temp = rnorm(60, 8, 1.5)),
                            data.frame(temp = rnorm(60, 14, 1.5)),
                            fit_density, n.rep = 19)
plot(result)

```
