# Bitchat IVS Fork

This repository is maintained as an IVS development fork of `permissionlesstech/bitchat`.

## Repository model

- Upstream: `permissionlesstech/bitchat`
- Fork: `ivsjsc/bitchat`
- Stable branch: `main`
- Development branch: `develop`
- Upstream baseline at fork creation: `9b84b361225facd8e623f25d76f889d3dc54a879`

IVS-specific work should be isolated in small commits so upstream changes can be merged or rebased with minimal protocol/core conflicts.

## IVS application identity

The IVS fork intentionally uses identifiers distinct from the upstream application so both builds can coexist and Apple signing assets cannot collide.

- Display name: `Bitchat IVS`
- Main bundle identifier: `com.ivsjsc.bitchat`
- Share extension bundle identifier: `com.ivsjsc.bitchat.ShareExtension`
- App Group: `group.com.ivsjsc.bitchat`
- URL scheme: `bitchativs`

Core Bitchat mesh/protocol naming is not mass-renamed. This preserves compatibility and reduces upstream merge risk.

## Free Personal Team iPhone install

For development/testing on your own iPhone, the repository includes a separate free Apple-ID path that does **not** require a paid Apple Developer Program membership, App Store Connect credentials, a distribution certificate, or GitHub Actions secrets.

The free path is intentionally local because Personal Team signing is tied to the Apple ID signed into Xcode and the physically connected iPhone. GitHub-hosted runners cannot replace that local Personal Team/device relationship.

### What the free path changes

`Configs/PersonalTeam.entitlements` is an empty entitlement profile used only by the local installer. `scripts/install-personal-team.sh` temporarily creates the gitignored `Configs/Local.xcconfig`, assigns a unique Personal Team bundle namespace, overrides both iOS targets to use automatic Apple Development signing, and strips the paid App Group entitlement from the build.

The Bitchat Bluetooth/mesh/protocol source is not changed. The Share Extension remains embedded and receives its own `${PRODUCT_BUNDLE_IDENTIFIER}.ShareExtension` identifier, but cross-process Share Extension handoff through the App Group is intentionally unavailable in the Personal Team build.

### Requirements

1. macOS with Xcode 15 or newer.
2. Sign in with the free Apple ID in **Xcode → Settings → Accounts** and make sure a **Personal Team** appears.
3. Connect the iPhone by USB (or a previously paired developer connection), trust the Mac, and enable **Developer Mode** on the iPhone if iOS requests it.
4. Obtain the Personal Team ID and the iPhone UDID.

### Build, package and install

From the repository root run:

```bash
TEAM_ID=YOUR_TEAM_ID \
DEVICE_UDID=YOUR_IPHONE_UDID \
bash scripts/install-personal-team.sh
```

The script performs the full local flow:

- creates/restores `Configs/Local.xcconfig` without committing personal signing data;
- gives the Personal Team build a unique bundle ID derived from the Team ID;
- builds the physical-device Debug app using automatic Apple Development provisioning;
- replaces the normal App Group entitlements with `Configs/PersonalTeam.entitlements`;
- verifies the app bundle ID, Share Extension bundle ID and code signature;
- fails if an App Group entitlement unexpectedly remains;
- packages a local `build/PersonalTeamExport/Bitchat-IVS-Personal.ipa` copy;
- installs the signed `.app` directly to the selected iPhone using `xcrun devicectl`.

You can override the default Personal Team bundle identifier when necessary:

```bash
PERSONAL_BUNDLE_ID=com.example.bitchat.personal \
TEAM_ID=YOUR_TEAM_ID \
DEVICE_UDID=YOUR_IPHONE_UDID \
bash scripts/install-personal-team.sh
```

Personal Team provisioning is temporary and must be re-signed/reinstalled when the free provisioning expires. This route is for development/testing, not TestFlight/App Store distribution.

## Apple signing policy

No Apple Team ID, private key, certificate, provisioning profile, or App Store Connect credential is committed to the repository.

For local paid-team development, copy `Configs/Local.xcconfig.example` to `Configs/Local.xcconfig` and set your Apple Developer Team ID. The local file is ignored by git.

For GitHub Actions signed builds, configure these repository secrets:

- `APPLE_TEAM_ID`
- `APPLE_DISTRIBUTION_CERTIFICATE_BASE64` — base64 of the exported Apple Distribution `.p12` containing its private key
- `APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD` — password used when exporting that `.p12`
- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_API_PRIVATE_KEY_BASE64`

The signed workflows import the distribution identity into an ephemeral keychain on the GitHub-hosted macOS runner, verify that an Apple Distribution identity exists, use the App Store Connect API key for automatic provisioning/export, and remove temporary signing material at the end of the job.

Before signed workflows can succeed, the Apple Developer account must own/configure:

1. App ID `com.ivsjsc.bitchat`.
2. App ID `com.ivsjsc.bitchat.ShareExtension`.
3. App Group `group.com.ivsjsc.bitchat` assigned to both identifiers.
4. An Apple Distribution certificate exported as `.p12` with its private key.
5. An App Store Connect app record matching `com.ivsjsc.bitchat` before TestFlight upload.
6. An App Store Connect API key with sufficient access for provisioning/export and upload.

## CI/CD

`.github/workflows/ivs-build-artifacts.yml` builds unsigned iOS Simulator and universal macOS artifacts. It is suitable for continuous build verification without Apple credentials and asserts the built IVS bundle identifier and display name.

`.github/workflows/ivs-ios-release.yml` is manual-only. It installs the Apple Distribution signing identity in an ephemeral keychain, authenticates with the App Store Connect API key, archives a signed device build, verifies the main app and Share Extension identifiers, code signatures and App Group entitlements, exports a signed App Store Connect IPA, and can optionally upload the archive to TestFlight.

### Direct-install iPhone IPA (paid Ad Hoc)

`.github/workflows/ivs-ios-device-ipa.yml` is a separate manual Ad Hoc release path for installing Bitchat IVS directly on registered iPhones.

Prerequisites:

1. The target iPhone must be registered in the Apple Developer account and its UDID must be known.
2. The Ad Hoc provisioning profiles generated for both the main app and Share Extension must include that iPhone.
3. The six signing secrets listed above must be configured in GitHub Actions.

Run **Actions → IVS iOS Device IPA → Run workflow**, enter the registered iPhone UDID, and start the job. The workflow:

- validates the UDID and required signing configuration;
- creates an ephemeral signing keychain;
- archives the Release build for a physical iOS device;
- exports using Apple `ad-hoc` distribution;
- verifies the main app, Share Extension, signatures and App Group entitlement;
- decodes both embedded provisioning profiles and fails unless the requested iPhone UDID is actually present;
- uploads `Bitchat-IVS-iPhone-AdHoc-IPA` as the GitHub Actions artifact;
- removes temporary signing material from the runner.

An Ad Hoc IPA is installable only on devices included in its provisioning profile. Adding a new iPhone requires registering its UDID and rebuilding the IPA.

## Upstream sync guardrail

When bringing in upstream changes:

1. Fetch/merge upstream into an integration branch first.
2. Preserve IVS identity values in `Configs/Release.xcconfig` and the plist metadata.
3. Do not rename transport/protocol constants solely for branding.
4. Run upstream `Build & Test`, `Dead Code`, and `IVS Build Artifacts` before merging to `main`.
5. Resolve semantic conflicts in security, transport, identity, persistence, and cryptography manually; never accept either side wholesale without review.
