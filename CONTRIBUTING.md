# Contributing to RecyclerView

Thanks for helping improve RecyclerView. Bug reports, documentation fixes and pull requests are all
welcome.

## Reporting a bug

Open an [issue](https://github.com/ulvi-vali/recycler-view-for-swiftui/issues/new/choose) with a
minimal reproduction, the library version, and the iOS and Xcode versions you use.

## Development setup

- Xcode 15 or later.
- Open `Package.swift` in Xcode to work on the library.
- Open `Examples/RecyclerViewExample/RecyclerViewExample.xcodeproj` to try a change in the example
  app, which builds against your local copy of the package.

## Running the tests

The library depends on UIKit, so the tests run on an iOS Simulator rather than with `swift test`:

```bash
xcodebuild test -scheme RecyclerView -destination 'platform=iOS Simulator,name=iPhone 16'
```

Use the name of any simulator installed on your Mac; `xcrun simctl list devices available` lists them.

## Pull requests

1. Branch from `master` and keep the change focused.
2. Add or update tests in `Tests/RecyclerViewTests` for the behaviour you change.
3. Document new public API with DocC comments.
4. Add an entry under **Unreleased** in `CHANGELOG.md`.
5. Check that CI passes.

## Releasing

1. Move the **Unreleased** entries in `CHANGELOG.md` under a heading for the new version.
2. Tag the release commit with the bare version number, such as `1.1.0`, and push the tag. Swift
   Package Manager resolves versions from these tags.
3. Publish a GitHub release for the tag with the changelog entries as its notes.
