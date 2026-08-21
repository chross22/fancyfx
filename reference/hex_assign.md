# Assign points to hexagons of a pointy-top lattice

Uses axial coordinates and cube rounding, which is the standard
construction and has the property the tests check: every point lands in
the hexagon whose centre is nearest to it.

## Usage

``` r
hex_assign(x, y, size)
```

## Arguments

- x, y:

  Numeric coordinate vectors.

- size:

  Hexagon size, centre to vertex.

## Value

A list of integer axial coordinates `q` and `r`.
