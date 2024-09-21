# Contributing

Contributions to Foundation are welcome! This project follows the [contribution guidelines for the Swift project](https://swift.org/contributing/#contributing-code).

Please see the [Foundation Evolution Process](Evolution.md) for any change that adds or modifies public API.

## Bug reports

We are using [GitHub Issues](https://github.com/apple/swift-foundation/issues) for tracking bugs, feature requests, and other work.

## Pull requests

Before embarking on a large amount of work to implement missing functionality, please double-check with the community in the [Swift Forums](https://forums.swift.org/). Someone may already be working in this area, and we want to avoid duplication of work.

## Review

Each pull request will be reviewed by a code owner before merging.

* Pull requests should contain small, incremental change.
* Focus on one task. If a pull request contains several unrelated commits, we will ask for the pull request to be split up.
* Please squash work-in-progress commits. Each commit should stand on its own (including the addition of tests if possible). This allows us to bisect issues more effectively.
* After addressing review feedback, please rebase your commit so that we create a clean history in the `main` branch.

## Tests

All pull requests which contain code changes should come with a new set of automated tests, and every current test must pass on all supported platforms.

## Documentation

When adding methods, please add associated documentation using the [DocC markdown syntax](https://www.swift.org/documentation/docc/).

