# Require terra, with an actionable message

terra is a Suggests rather than an Imports: the spatial plots are a
corner of this package, and most users plotting a GLM should not have to
install a geospatial stack to do it.

## Usage

``` r
require_terra()
```

## Value

Invisibly `TRUE`.
