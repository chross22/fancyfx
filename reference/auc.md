# Area under the ROC curve

Computed from ranks rather than by integrating the curve. The rank form
is the Mann-Whitney U statistic, which handles tied predictions exactly
by giving them mid-ranks; trapezoidal integration over a curve with ties
gives a slightly different answer depending on how the ties were
ordered.

## Usage

``` r
auc(observed, predicted)
```

## Arguments

- observed:

  0/1 numeric vector.

- predicted:

  Numeric vector of predicted probabilities.

## Value

The AUC, a single number.
