# Changelog Rules

These rules define how `CHANGELOG.md` must be updated for each release.

## Versioning

- Follow SemVer: `MAJOR.MINOR.PATCH`.
- `MAJOR`: breaking API changes.
- `MINOR`: new features, non-breaking API expansion.
- `PATCH`: bug fixes, docs, test-only changes without behavior break.

## Entry format

- Keep newest version at the top.
- Use heading format: `## x.y.z`.
- Each bullet must describe user-visible impact.
- Group related bullets by feature area when useful.
- Avoid vague entries like "misc fixes".

## What to include

- API additions/removals/renames.
- Behavior changes affecting integration.
- New configuration options and defaults.
- Bug fixes that alter runtime behavior.
- Test additions for critical behavior.
- Compliance/license changes.

## What not to include

- Internal refactors with zero user-visible impact.
- Pure formatting/style edits.
- Temporary debugging changes.

## Release checklist

1. Update package version in `pubspec.yaml`.
2. Add a new top section to `CHANGELOG.md`.
3. Run:
   - `flutter analyze`
   - `flutter test`
4. Create annotated git tag: `vX.Y.Z`.
