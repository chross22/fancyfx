# Check an argument against its allowed values

[`match.arg()`](https://rdrr.io/r/base/match.arg.html) would do this,
but its message names the formal argument rather than the value that was
wrong, and these functions have said "Unknown type requested: x" since
they were written. Kept, because the message is better.

## Usage

``` r
check_choice(value, allowed, label)
```

## Arguments

- value:

  the value given

- allowed:

  the values accepted

- label:

  what to call it in the error message

## Value

`value`, unchanged
