# Contributing

This document contains notes about development and testing of swift-toolchain-sarif.

## Building & Testing

swift-toolchain-sarif is a SwiftPM package, so you can build and test it using anything that supports packages - opening in Xcode, Visual Studio Code with [Swift for Visual Studio Code](https://github.com/swift-server/vscode-swift) installed, or through the command line using `swift build` and `swift test`.

## Formatting

swift-toolchain-sarif is formatted using [swift-format](http://github.com/swiftlang/swift-format) to ensure a consistent style.

To format your changes run the formatter using the following command
```bash
swift format --in-place --parallel --recursive .
# Or alternatively
swift format -ipr .
```

> [!NOTE]
> You can add a git hook to ensure all commits to the swift-toolchain-sarif repository are correctly formatted.
> 1. Save the following contents to `swift-toolchain-sarif/.git/hooks/pre-commit`
> ```bash
> #!/usr/bin/env bash
> set -e
> SOURCE_DIR=$(realpath "$(dirname $0)/../..")
> swift format lint --strict --parallel --recursive $SOURCE_DIR
> ```
> 2. Mark the file as executable: `chmod a+x swift-toolchain-sarif/.git/hooks/pre-commit`
> 3. If you have global git hooks installed, be sure to call them at the end of the script with `path/to/global/hooks/pre-commit "$@"`


## Testing

All of the tests for swift-toolchain-sarif are implemented using Swift Testing. To run the tests for the entire package, run:

```bash
swift test
```

## Authoring commits

Prefer to squash the commits of your PR (*pull request*) and avoid adding commits like “Address review comments”. This creates a clearer git history, which doesn’t need to record the history of how the PR evolved.

We prefer to not squash commits when merging a PR because, especially for larger PRs, it sometimes makes sense to split the PR into multiple self-contained chunks of changes. For example, a PR might do a refactoring first before adding a new feature or fixing a bug. This separation is useful for two reasons:
- During review, the commits can be reviewed individually, making each review chunk smaller
- In case this PR introduced a bug that is identified later, it is possible to check if it resulted from the refactoring or the actual change, thereby making it easier find the lines that introduce the issue.

## Opening a PR

To submit a PR you don't need permissions on this repo, instead you can fork the repo and create a PR through your forked version.

For more information and instructions, read the GitHub docs on [forking a repo](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/fork-a-repo).

Once you've pushed your branch, you should see an option on this repository's page to create a PR from a branch in your fork.

> [!TIP]
> If you are stuck, it’s encouraged to submit a PR that describes the issue you’re having, e.g. if there are tests that are failing, build failures you can’t resolve, or if you have architectural questions. We’re happy to work with you to resolve those issue.

### Opening a PR for Release Branch

See the [dedicated section](https://www.swift.org/contributing/#release-branch-pull-requests) on the Swift project website.

## Review and CI Testing

After you opened your PR, a maintainer will review it and test your changes in CI (*Continuous Integration*) by adding a `@swift-ci Please test` comment on the pull request. Once your PR is approved and CI has passed, the maintainer will merge your pull request.

Only contributors with [commit access](https://www.swift.org/contributing/#commit-access) are able to approve pull requests and trigger CI.

## Swift Version

We require that swift-toolchain-sarif builds with the latest released compiler and the previous major version (e.g. with Swift 6.4 and Swift 6.3).
