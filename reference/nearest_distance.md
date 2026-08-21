# Distance from each point to the nearest reference point

Distance from each point to the nearest reference point

## Usage

``` r
nearest_distance(points, reference, geo = FALSE)
```

## Arguments

- points:

  Two-column matrix of coordinates.

- reference:

  Two-column matrix of coordinates.

- geo:

  Whether to use great-circle distances.

## Value

A numeric vector, one distance per row of `points`.
