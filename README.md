# `io-classes` based utilities

This repository hosts the following packages, which are based on the
[`io-classes`](https://hackage.haskell.org/package/io-classes) package:

- [`strict-checked-vars`](./strict-checked-vars): strict variables that hold an
  invariant that must be maintained when writing values to the variables.
- [`resource-registry`](./resource-registry): a data structure that keeps track
  of resources and manage their deallocation.
- [`rawlock`](./rawlock): a read-append-write lock.
