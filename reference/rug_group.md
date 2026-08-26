# The factor a rug is split by

Resolves `group` against the data and the palette, and returns the data
it should be drawn from alongside it – levels the palette does not name
are dropped, since drawing them would hand a band of rug the colour of a
curve it has nothing to do with.

## Usage

``` r
rug_group(dat, group, palette = NULL)
```

## Arguments

- dat:

  Raw data, already a data frame.

- group:

  A column name, or `NULL` for an undivided rug.

- palette:

  Colours for the split, optionally named by level.

## Value

A list of `group` – the column name, or `NULL` for an undivided rug –
the `data` to draw it from, and the `palette` to colour it with, named
by level.
