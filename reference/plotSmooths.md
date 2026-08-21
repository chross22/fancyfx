# Extract and plot smooths from a GAM (deprecated)

**\[Deprecated\]**

`plotSmooths()` was the GAM-only ancestor of
[`plotEffects()`](https://camilleross.org/fancyfx/reference/plotEffects.md).
It still works and still returns the same plot, but it warns once per
session and will be removed in a future release. Rename the call: every
argument is unchanged, and the defaults (`scale = "link"`,
`interval = "se"`) reproduce exactly what `plotSmooths()` drew.

## Usage

``` r
plotSmooths(
  model,
  dat,
  var,
  xlab = var,
  ylab = "Partial Effect",
  transform = c("none", "log", "log10", "sqrt"),
  rug.type = c("histogram", "density"),
  bins = 30
)
```

## Arguments

- model:

  GAM produced using mgcv.

- dat:

  Raw data used to fit the model, for the accompanying rug plot.

- var:

  Variable smooths to extract.

- xlab:

  Label for the x-axis. Defaults to the variable's own name.

- ylab:

  Label for y-axis of smooth plot; default is `"Partial Effect"`.

- transform:

  Optional parameter indicating how to transform the variable, if
  applicable.

- rug.type:

  Type of rug plot to draw beneath the smooth.

- bins:

  Number of bins for a histogram rug.

## Value

A smooth plot for `var` with its rug plot above it.

## See also

[`plotEffects()`](https://camilleross.org/fancyfx/reference/plotEffects.md),
which replaces this function.

Other effect plots:
[`combinePlots()`](https://camilleross.org/fancyfx/reference/combinePlots.md),
[`comparePlots()`](https://camilleross.org/fancyfx/reference/comparePlots.md),
[`plotEffects()`](https://camilleross.org/fancyfx/reference/plotEffects.md),
[`plotRugs()`](https://camilleross.org/fancyfx/reference/plotRugs.md)

## Examples

``` r
gam.fit <- mgcv::gam(Petal.Length ~ s(Sepal.Length), data = iris)

# Deprecated:
# plotSmooths(gam.fit, iris, "Sepal.Length")

# Use instead:
plotEffects(gam.fit, iris, "Sepal.Length")

```
