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

## Apple signing policy

No Apple Team ID, private key, certificate, provisioning profile, or App Store Connect credential is committed to the repository.

For local development, copy `Configs/Local.xcconfig.example` to `Configs/Local.xcconfig` and set your Apple Developer Team ID. The local file is ignored by git.

For GitHub Actions signed builds, configure these repository secrets:

- `APPLE_TEAM_ID`
- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_API_PRIVATE_KEY_BASE64`

Before the signed workflow can succeed, the Apple Developer account must own/configure:

1. App ID `com.ivsjsc.bitchat`.
2. App ID `com.ivsjsc.bitchat.ShareExtension`.
3. App Group `group.com.ivsjsc.bitchat` assigned to both identifiers.
4. An App Store Connect app record matching `com.ivsjsc.bitchat` before TestFlight upload.
5. An App Store Connect API key with sufficient access for signing/provisioning and upload.

## CI/CD

`.github/workflows/ivs-build-artifacts.yml` builds unsigned iOS Simulator and universal macOS artifacts. It is suitable for continuous build verification without Apple credentials.

`.github/workflows/ivs-ios-release.yml` is manual-only. It authenticates with the App Store Connect API key, archives a signed device build, verifies code signing and entitlements, exports a signed IPA, and can optionally upload the archive to TestFlight.

## Upstream sync guardrail

When bringing in upstream changes:

1. Fetch/merge upstream into an integration branch first.
2. Preserve IVS identity values in `Configs/Release.xcconfig` and the configurable `APP_DISPLAY_NAME` project settings.
3. Do not rename transport/protocol constants solely for branding.
4. Run upstream `Build & Test`, `Dead Code`, and `IVS Build Artifacts` before merging to `main`.
5. Resolve semantic conflicts in security, transport, identity, persistence, and cryptography manually; never accept either side wholesale without review.
