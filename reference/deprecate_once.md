# Warn once per session

A hand-rolled stand-in for
[`lifecycle::deprecate_soft()`](https://lifecycle.r-lib.org/reference/deprecate_soft.html).
Adding lifecycle to Imports is not worth it for one deprecation.

## Usage

``` r
deprecate_once(id, ...)
```

## Arguments

- id:

  Identifier for this notice, so each one fires independently.

- ...:

  Pieces of the message, pasted together.

## Value

Invisibly `NULL`, called for its side effect.
