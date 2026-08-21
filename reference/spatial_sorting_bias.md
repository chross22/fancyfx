# Spatial sorting bias in a train/test split

Asks whether a hold-out is really independent. If the test presences
happen to sit closer to the training presences than the test absences
do, the model can score well by knowing roughly where the training data
was, without knowing anything about the species.

## Usage

``` r
spatial_sorting_bias(presence, absence, reference, geo = FALSE)
```

## Arguments

- presence:

  Test presences: a two-column matrix or data frame of coordinates.

- absence:

  Test absences or background points, likewise.

- reference:

  Training presences, likewise.

- geo:

  Whether the coordinates are longitude and latitude, in which case
  distances are great-circle rather than Euclidean.

## Value

A named vector: `presence` and `absence` mean nearest-neighbour
distances, and their ratio `ssb`.

## Details

The statistic is the ratio of two mean nearest-neighbour distances: from
each test presence to the closest training presence, over the same for
each test absence, following Hijmans (2012).

- **Near 1** – test presences and test absences are equally far from the
  training data. The split is doing its job.

- **Near 0** – test presences sit much closer to training presences. A
  model can then score well on proximity alone, and its AUC is measuring
  the split rather than the species.

This is the quantity behind the warnings elsewhere in this package about
random cross-validation folds on spatially correlated data. Those
warnings say the problem exists; this measures how bad it is for a
particular split, which is the thing worth reporting in a methods
section.

A low value is not a reason to abandon the model. It is a reason to use
spatially blocked folds, or to sample the test absences to match the
presences' distance distribution, and then to say which you did.

## References

Hijmans, R. J. (2012). Cross-validation of species distribution models:
removing spatial sorting bias and calibration with a null model.
*Ecology*, 93(3), 679-688.
[doi:10.1890/11-0826.1](https://doi.org/10.1890/11-0826.1)

## See also

[`threshold_metrics()`](https://camilleross.org/fancyfx/reference/threshold_metrics.md),
whose `folds` argument is where a spatially blocked split gets used.

Other evaluation plots:
[`calc_deviance()`](https://camilleross.org/fancyfx/reference/calc_deviance.md),
[`calibration_estimates()`](https://camilleross.org/fancyfx/reference/calibration_estimates.md),
[`held_out()`](https://camilleross.org/fancyfx/reference/held_out.md),
[`permutation_importance()`](https://camilleross.org/fancyfx/reference/permutation_importance.md),
[`plotCalibration()`](https://camilleross.org/fancyfx/reference/plotCalibration.md),
[`plotImportance()`](https://camilleross.org/fancyfx/reference/plotImportance.md),
[`plotROC()`](https://camilleross.org/fancyfx/reference/plotROC.md),
[`plotThreshold()`](https://camilleross.org/fancyfx/reference/plotThreshold.md),
[`threshold_metrics()`](https://camilleross.org/fancyfx/reference/threshold_metrics.md)

## Examples

``` r
set.seed(1)
training <- cbind(runif(100, 0, 10), runif(100, 0, 10))

# Test presences drawn from the same area as the training data, test
# absences from everywhere: the split flatters the model.
biased.presence <- cbind(runif(50, 0, 10), runif(50, 0, 10))
absence <- cbind(runif(50, 0, 40), runif(50, 0, 40))

spatial_sorting_bias(biased.presence, absence, training)
#>    presence     absence         ssb 
#>  0.55186480 18.85275858  0.02927236 
```
