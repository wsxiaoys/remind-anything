# Contributing

## Development environment setup

### Prerequisites

- macOS 14 (Sonoma) or later
- Swift 5.9+ toolchain / Xcode 15+

### Building the app

Use the build script to produce a runnable `.app` bundle under `dist/`:

```bash
./Scripts/build_app.sh
open "dist/Remind Anything.app"
```

Whenever you want to test a change (or hand a build to someone for feedback),
re-run `Scripts/build_app.sh` to regenerate the distribution in `dist/`.

### Keeping macOS permissions across rebuilds

Remind Anything needs Screen Recording, Accessibility, and Automation
permissions. macOS stores these grants in its TCC database keyed to the app's
**code-signing identity**. An ad-hoc signature changes the app's identity on
every build, which resets those grants — forcing you to remove and re-grant each
permission after every rebuild.

To avoid this, create a stable self-signed code-signing certificate **once**:

```bash
./Scripts/create_dev_cert.sh
```

This creates a certificate named `RemindAnything Dev` that `build_app.sh`
auto-detects and signs with. With a stable identity, granted permissions persist
across rebuilds.

> The first build after creating the certificate will still require you to grant
> permissions one final time; subsequent rebuilds keep them.

### Distribution builds

For a notarizable, hardened-runtime build, pass a Developer ID identity:

```bash
./Scripts/build_app.sh --sign "Developer ID Application: NAME (TEAMID)"
```
