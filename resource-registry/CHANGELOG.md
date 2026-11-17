# Revision history of `resource-registry`

## 0.4.0.1 - xxxx-xx-xx

* Fix a memory leak: each thread from `forkThread`, `forkLinkedThread`,
  `withThread`, or `allocateThread` kept one entry in the registry until the
  registry was closed.
* Fix a memory leak: a thread that finished before `forkThread` returned
  stayed in the registry until the registry was closed.

## 0.4.0.0 - 2026-07-15

* Added `MonadEvaluate m` constraint to multiple functions.

## 0.3.0.0 - 2026-07-13

* Removed `transferRegistry`.

## 0.2.1.0 - 2026-03-04

* Define `impossibleToNotTransfer` for fundamental resource allocation in
  `WithTempRegistry`.

## 0.2.0.0 — 2025-10-23

* Define `transferRegistry` for moving all resources from one registry to a
  different one.

* Cancel registered threads in the registry before closing the registry. This
  prevents race conditions where the registry gets closed but the running async
  thread still tries to allocate something in the registry before being
  cancelled, which would result in an exception.

* Expose `allocateThread` to register another thread in a registry, such that it
  is cancelled before closing the registry, even if it belongs to a separate
  registry.

* Add the label of the thread to `Context`.

## 0.1.1.0 — 2025-05-15

* Use `io-classes-1.8`.

## 0.1.0.0 — 2024-10-22

- First release, extracted from [`ouroboros-consensus`](https://github.com/IntersectMBO/ouroboros-consensus).
