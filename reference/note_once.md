# Note something once per session

A message rather than a warning: these are caveats worth reading, not
signs that anything has gone wrong.
[`suppressMessages()`](https://rdrr.io/r/base/message.html) silences
them.

## Usage

``` r
note_once(id, ...)
```

## Arguments

- id:

  Identifier for this notice, so each one fires independently.

- ...:

  Pieces of the message, pasted together.

## Value

Invisibly `NULL`, called for its side effect.
