# The evaluation pairs a held_out() object already carries

The short circuit in
[`evaluation_pairs()`](https://camilleross.org/fancyfx/reference/evaluation_pairs.md).
There is no model to unwrap, no response column to find and no
prediction to make; the work is the checking that the model path does
after predicting.

## Usage

``` r
held_out_pairs(x, folds = NULL, require.both.classes = TRUE)
```

## Arguments

- x:

  A `fancyfx_held_out` object.

- folds:

  Optional fold identifiers, one per observation.

- require.both.classes:

  Whether to refuse data containing only one outcome class.

## Value

The same list
[`evaluation_pairs()`](https://camilleross.org/fancyfx/reference/evaluation_pairs.md)
returns.
