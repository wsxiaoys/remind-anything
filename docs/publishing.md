# Publishing Remind Anything via Homebrew Cask

This document describes the **paid / notarized** distribution path: sign with a
Developer ID certificate, notarize + staple, package a DMG, publish a GitHub
Release, and install through a Homebrew Cask.

> **Why notarization is required.** As of Homebrew 5.0 (Nov 2025), `brew` no
> longer strips the Gatekeeper quarantine bit (`--no-quarantine` is deprecated),
> and **all casks that fail Gatekeeper checks are removed from the official tap
> after September 1, 2026**. Apple Silicon also refuses to run un-notarized,
> downloaded binaries cleanly. A notarized build is therefore the only path that
> installs and launches with no manual `xattr` step. See
> [`docs/homebrew-notes.md`](#references) links at the bottom.

---

## 0. Overview

```mermaid
flowchart TD
    A[swift build + assemble .app] --> B[codesign: Developer ID Application + hardened runtime]
    B --> C[create-dmg: Remind-Anything-VERSION.dmg]
    C --> D[notarytool submit --wait]
    D --> E[stapler staple .dmg]
    E --> F[GitHub Release: upload .dmg]
    F --> G[shasum -a 256 -> Cask sha256]
    G --> H[Casks/remind-anything.rb in personal tap]
    H --> I[brew install --cask you/tap/remind-anything]
```

The scripts below automate everything up to the GitHub Release:

| Script | Purpose |
|---|---|
| `Scripts/build_app.sh --sign …` | Build + Developer ID sign (hardened runtime). |
| `Scripts/make_dmg.sh` | Version-aware DMG packaging (via `create-dmg`). |
| `Scripts/notarize.sh` | `notarytool submit --wait` → staple → Gatekeeper check. |
| `Scripts/release.sh --sign …` | Runs all of the above, then prints the Cask `sha256`. |

---

## 1. One-time prerequisites

| Requirement | How |
|---|---|
| **Apple Developer Program** ($99/yr) | Enroll at <https://developer.apple.com/programs/> |
| **Developer ID Application certificate** | Xcode → Settings → Accounts → Manage Certificates → `+` → *Developer ID Application*. Verify with `security find-identity -p codesigning`. |
| **Notary credentials stored in keychain** | `xcrun notarytool store-credentials "RemindAnything-Notary" --apple-id "you@example.com" --team-id "TEAMID"` (uses an app-specific password) — or use an App Store Connect API key. ✅ Profile `RemindAnything-Notary` is already stored (team `8TV34LSJW3`). |
| **`create-dmg`** | `brew install create-dmg` |

Record your Team ID and the exact identity string, e.g.
`Developer ID Application: Meng Zhang (ABCDE12345)`.

---

## 2. Bump the version

Update **both** keys in `App/Info.plist` for each release:

- `CFBundleShortVersionString` — marketing version (e.g. `1.0.0`), used by the Cask.
- `CFBundleVersion` — monotonically increasing build number (e.g. `1`).

Tag matches the version: `v1.0.0`.

---

## 3. Sign

```sh
Scripts/build_app.sh --sign "Developer ID Application: Meng Zhang (ABCDE12345)"
```

Verify the signature and hardened runtime:

```sh
codesign --verify --deep --strict --verbose=2 "dist/Remind Anything.app"
codesign -dv --verbose=4 "dist/Remind Anything.app" 2>&1 | grep -E 'Authority|flags'
# flags should include: runtime
```

---

## 4. Package the DMG

Produce `dist/Remind-Anything-<version>.dmg` (version read from `App/Info.plist`)
with a drag-to-Applications layout:

```sh
Scripts/make_dmg.sh
```

---

## 5. Notarize + staple

```sh
# Defaults to the newest dist/Remind-Anything-*.dmg and profile "RemindAnything-Notary":
Scripts/notarize.sh
```

This submits with `notarytool --wait`, staples the ticket into the DMG, and runs
the Gatekeeper check (expected: `source=Notarized Developer ID … accepted`).

If notarization fails, fetch the log with the submission ID:

```sh
xcrun notarytool log <submission-id> --keychain-profile "RemindAnything-Notary"
```

Common causes: a nested binary not signed with the hardened runtime, or missing
`--options runtime` (already handled by `build_app.sh`).

> **Shortcut:** `Scripts/release.sh --sign "Developer ID Application: … (TEAMID)"`
> runs steps 3–5 and prints the `sha256` for the Cask in one go.

---

## 6. Publish a GitHub Release

The Cask needs a **stable HTTPS download URL**. GitHub Releases are the simplest.

```sh
VERSION=1.0.0
gh release create "v${VERSION}" \
  "dist/Remind-Anything-${VERSION}.dmg" \
  --title "Remind Anything ${VERSION}" \
  --notes "Release notes here."

# Compute the checksum for the Cask:
shasum -a 256 "dist/Remind-Anything-${VERSION}.dmg"
```

Download URL pattern:
`https://github.com/wsxiaoys/remind-anything/releases/download/v<version>/Remind-Anything-<version>.dmg`

---

## 7. Personal Homebrew tap

Fastest route that works immediately (no notability review needed).

1. Create a repo named `homebrew-tap` under your account (the `homebrew-` prefix
   is what makes `brew tap` recognize it).
2. Copy [`Casks/remind-anything.rb`](../Casks/remind-anything.rb) from this repo
   into `Casks/remind-anything.rb` in the tap, bumping `version` + `sha256` on
   each release (both printed by `Scripts/release.sh`). The current file:

```ruby
cask "remind-anything" do
  version "1.0.0"
  sha256 "ea464b8a0af15087a8e1b87dfd50dba9cf013709fcca1870efa8e08c85e224c5"

  url "https://github.com/wsxiaoys/remind-anything/releases/download/v#{version}/Remind-Anything-#{version}.dmg"
  name "Remind Anything"
  desc "Capture anything on screen, attach a note, get reminded with context"
  homepage "https://github.com/wsxiaoys/remind-anything"

  depends_on macos: ">= :sonoma" # macOS 14+, matches LSMinimumSystemVersion

  app "Remind Anything.app"

  zap trash: [
    "~/Library/Application Support/RemindAnything",
    "~/Library/Preferences/com.mengzhang.RemindAnything.plist",
  ]
end
```

3. Install / test locally:

```sh
brew tap wsxiaoys/tap
brew install --cask wsxiaoys/tap/remind-anything

# Audit the cask before publishing changes:
brew audit --cask --new wsxiaoys/tap/remind-anything
brew style wsxiaoys/tap/remind-anything
```

Users then install with:

```sh
brew install --cask wsxiaoys/tap/remind-anything
```

---

## 8. (Optional, later) Submit to the official homebrew-cask

Only worthwhile once the app has a stable release history and meets the
[Acceptable Casks](https://docs.brew.sh/Acceptable-Casks) notability rules
(popularity/notability thresholds). The Cask above is largely reusable; open a
PR against `Homebrew/homebrew-cask`. Until eligible, keep the personal tap.

---

## 9. Release checklist

- [ ] Bump `CFBundleShortVersionString` + `CFBundleVersion` in `App/Info.plist`.
- [ ] `Scripts/build_app.sh --sign "Developer ID Application: … (TEAMID)"`.
- [ ] `codesign --verify --deep --strict` passes; `flags=…runtime`.
- [ ] Build DMG (`create-dmg`).
- [ ] `notarytool submit --wait` → **Accepted**; `stapler staple`.
- [ ] `spctl -a -t open …` → **accepted / Notarized Developer ID**.
- [ ] `gh release create v<version>` with the stapled DMG.
- [ ] Update `version` + `sha256` in `Casks/remind-anything.rb`; push tap.
- [ ] `brew audit --cask` + fresh `brew install --cask` smoke test.

---

## 10. Follow-up automation

Built (under `Scripts/`):

- ✅ `make_dmg.sh` — version-aware DMG packaging.
- ✅ `notarize.sh` — submit + wait + staple + verify.
- ✅ `release.sh` — build (signed) → dmg → notarize → staple → print sha256.
- ✅ `.github/workflows/release.yml` — tag-triggered CI release (see §11).

There is **no auto-update** mechanism (Sparkle); updates flow through
`brew upgrade --cask`.

---

## 11. GitHub Actions release workflow

`.github/workflows/release.yml` runs the whole signed+notarized release on a
`macos-14` runner whenever you push a `v*` tag. It imports the Developer ID cert
into a throwaway keychain, stores the notary profile, runs `Scripts/release.sh`,
then creates a GitHub Release with the stapled DMG.

### 11.1 Export the Developer ID certificate

On the Mac that holds the *Developer ID Application* cert + private key:

1. **Keychain Access** → *login* keychain → *My Certificates*.
2. Right-click the *Developer ID Application: …* entry → **Export…** → save as
   `DeveloperID.p12`, and set an export password.
3. Base64-encode it for the secret:

   ```sh
   base64 -i DeveloperID.p12 | pbcopy   # now in your clipboard
   ```

### 11.2 Configure repository secrets

Add these under **Settings → Secrets and variables → Actions → New repository secret**:

| Secret | Value |
|---|---|
| `DEVELOPER_ID_CERT_P12_BASE64` | Base64 from step 11.1 |
| `DEVELOPER_ID_CERT_PASSWORD` | The `.p12` export password |
| `KEYCHAIN_PASSWORD` | Any throwaway string (a fresh CI keychain password) |
| `SIGN_IDENTITY` | `Developer ID Application: <Name> (8TV34LSJW3)` |
| `NOTARY_APPLE_ID` | `meng@tabbyml.com` |
| `NOTARY_TEAM_ID` | `8TV34LSJW3` |
| `NOTARY_PASSWORD` | App-specific password (appleid.apple.com → Sign-In & Security) |

> The signing identity's team and `NOTARY_TEAM_ID` **must match**. The
> app-specific password is *not* your Apple ID password — generate one at
> <https://appleid.apple.com>.

### 11.3 Cut a release

```sh
# Bump versions in App/Info.plist first (see §2), commit, then:
git tag v1.0.0
git push origin v1.0.0
```

The workflow's job summary prints the DMG path and its `sha256`. Copy the
`sha256` into `Casks/remind-anything.rb` (§7) and push your tap.

> **Note:** the workflow only *publishes the release*. Updating the Cask's
> `version`/`sha256` in your tap is still a manual step (or add a follow-up job
> that commits to the tap repo with a PAT).

---

## References

- Homebrew 5.0.0 announcement — <https://brew.sh/2025/11/12/homebrew-5.0.0/>
- Removing `--no-quarantine` support — <https://github.com/Homebrew/brew/issues/20755>
- Acceptable Casks — <https://docs.brew.sh/Acceptable-Casks>
- Notarizing with `notarytool` — <https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution>
