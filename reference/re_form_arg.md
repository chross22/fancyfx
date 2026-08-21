# Name of the random-effects argument for this model class

brms calls it `re_formula`; lme4, glmmTMB and rstanarm call it
`re.form`. Passing the wrong one to a `brmsfit` still reaches the
prediction function, but `marginaleffects` warns that the argument is
not one it recognises for the class – noise on every panel, and a sign
the call is relying on something not guaranteed to keep working.

## Usage

``` r
re_form_arg(model)
```

## Arguments

- model:

  A fitted model.

## Value

The argument name, as a string.
