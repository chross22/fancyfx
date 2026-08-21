# Warn about an argument in `...` that looks like a misspelled formal

`...` legitimately carries arguments through to the modelling backends,
so unknown names cannot simply be refused. But that makes a typo silent:
a misspelled `rug.type` is passed to `gratia`, ignored there, and the
plot comes back with the default rug and no complaint. This catches the
case that matters – a name that is almost certainly a formal argument
spelled wrong – while leaving genuine backend arguments alone.

## Usage

``` r
warn_misspelled_dots(dots.names, formals.names)
```

## Arguments

- dots.names:

  Names of the arguments captured by `...`.

- formals.names:

  Formal argument names of the calling function.

## Value

Invisibly `NULL`, called for its side effect.

## Details

Matching is deliberately tight. A name qualifies only if, ignoring case
and any dots or underscores, it either equals a formal argument exactly
or is one character away from one. Anything looser would start flagging
real backend arguments.
