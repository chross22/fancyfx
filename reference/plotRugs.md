# Create rug plots representing distribution of the raw data

The companion to a smooth plot: it shows where the data actually is, so
a bend in a smooth can be read against how much evidence sits under it.

## Usage

``` r
plotRugs(
  dat,
  var,
  type = c("histogram", "density"),
  transform = c("none", "log", "log10", "sqrt"),
  bins = 30,
  fill = "grey35"
)
```

## Arguments

- dat:

  Raw data

- var:

  Variable to plot

- type:

  Optional parameter indicating type of plot; default is histogram

- transform:

  Optional parameter indicating how to transform the variable, if
  applicable

- bins:

  Number of histogram bins. Set explicitly rather than left to
  `geom_histogram()`'s default, which is the same 30 but emits a message
  about it on every plot. Ignored when `type` is `"density"`.

- fill:

  Fill colour for the rug. Deliberately a neutral grey: the rug reports
  where the data is, and should not compete with the effect curve below
  it for attention.

## Value

The rug plot from dat for var

## See also

[`plotEffects()`](https://camilleross.org/fancyfx/reference/plotEffects.md),
which stacks this above an effect curve for you.

Other effect plots:
[`combinePlots()`](https://camilleross.org/fancyfx/reference/combinePlots.md),
[`comparePlots()`](https://camilleross.org/fancyfx/reference/comparePlots.md),
[`plotEffects()`](https://camilleross.org/fancyfx/reference/plotEffects.md),
[`plotSmooths()`](https://camilleross.org/fancyfx/reference/plotSmooths.md)

## Examples

``` r
plotRugs(iris, "Sepal.Length")

plotRugs(iris, "Sepal.Length", type = "density")

plotRugs(mtcars, "disp", transform = "log10", bins = 15)

```
