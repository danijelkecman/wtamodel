# WTA Model (SwiftUI)

## What it does

This app demonstrates **Weapon-Target Assignment (WTA)** model:

- define a small set of threats
- assign a limited number of interceptors
- compare an **exact brute-force** allocation with a **greedy heuristic**
- compute expected defended value using a per-shot engagement matrix:

```swift
P(kill) = pTrack * (1 - Π(1 - p[i][j]))
```

## What it does not do

This project is intentionally simplified. It does **not** model:

- correlated failures
- timing and engagement windows
- decoys and discrimination
- uncertain kill assessment
- weapon-specific vs target-specific probability matrices
- dynamic reallocation over time

## Better next steps

- [x] replace scalar `sspk` with a per-shot `p[i][j]` profile generated from each threat's base probability and follow-on decay
- [x] add Monte Carlo uncertainty with configurable sample count and per-threat uncertainty bands
- [x] add sequential shoot-look-shoot logic for expected interceptor consumption
- [x] add charts for marginal gain and diminishing returns
- [x] add scenario import/export as JSON
