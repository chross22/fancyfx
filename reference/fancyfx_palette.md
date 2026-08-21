# Colours for effects split into several curves

A six-colour categorical palette, used when an effect splits by a factor
– a factor-smooth interaction, most often. Assigned in the order given.

## Usage

``` r
fancyfx_palette(n = 6)
```

## Arguments

- n:

  How many colours to return. Defaults to all six.

## Value

A character vector of hex colours.

## Details

Chosen by search rather than by eye, and checked against the properties
that decide whether a reader can actually tell two curves apart: every
colour sits in a mid lightness band, carries enough chroma not to read
as grey, clears a 3:1 contrast ratio against a white page, and stays
separable under simulated protanopia and deuteranopia.

All pairs clear the colour-vision-deficiency floor. The fifth and sixth
colours are the closest pair and sit between the floor and the
comfortable target, which is why a legend is always drawn – identity is
never carried by colour alone.

Six is the limit. Past that, colours stop being tellable apart no matter
how they are chosen, and a facet per level communicates far better than
a seventh hue;
[`plotEffects()`](https://camilleross.org/fancyfx/reference/plotEffects.md)
says so rather than inventing one.

## See also

[`theme_fancyfx()`](https://camilleross.org/fancyfx/reference/theme_fancyfx.md)
for the matching theme.

## Examples

``` r
fancyfx_palette()
#> [1] "#215689" "#B58D2D" "#346210" "#C368FD" "#B4677A" "#1892A3"
fancyfx_palette(3)
#> [1] "#215689" "#B58D2D" "#346210"
```
