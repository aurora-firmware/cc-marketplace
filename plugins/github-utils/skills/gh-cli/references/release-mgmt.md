# Release Management — Full Reference

## Contents
1. [Creating releases](#creating-releases)
2. [Uploading and managing assets](#uploading-and-managing-assets)
3. [Changelogs](#changelogs)
4. [Prerelease promotion](#prerelease-promotion)
5. [Attestation](#attestation)

---

## Creating Releases

```bash
# Minimal — tag only
gh release create v1.2.3

# With title and auto-generated notes from merged PRs
gh release create v1.2.3 \
  --title "v1.2.3 — Performance improvements" \
  --generate-notes

# Draft release (not public until published)
gh release create v1.2.3 --draft --generate-notes

# Prerelease
gh release create v2.0.0-beta.1 --prerelease --title "v2.0 beta 1"

# Target a specific branch or commit instead of current HEAD
gh release create v1.2.3 --target release/1.x

# Include assets at creation time
gh release create v1.2.3 dist/app-linux dist/app-darwin dist/app-win.exe
```

---

## Uploading and Managing Assets

```bash
# Upload assets to an existing release
gh release upload v1.2.3 ./dist/app-linux-amd64 ./dist/app-darwin-arm64

# Upload with a custom label (display name)
gh release upload v1.2.3 ./dist/checksums.txt#"SHA-256 checksums"

# Overwrite if the asset already exists
gh release upload v1.2.3 ./dist/app-linux --clobber

# Download assets from a release
gh release download v1.2.3                          # all assets
gh release download v1.2.3 --pattern "*.tar.gz"     # filtered
gh release download v1.2.3 --dir ./downloads

# Download the latest release
gh release download --pattern "*.tar.gz"             # omit tag = latest

# List all releases
gh release list

# View release details
gh release view v1.2.3
gh release view v1.2.3 --json assets --jq '.[].name'

# Edit release metadata
gh release edit v1.2.3 --title "v1.2.3 — Hotfix" --prerelease=false

# Delete a release (does not delete the tag)
gh release delete v1.2.3
gh release delete v1.2.3 --yes --cleanup-tag      # also delete the tag
```

---

## Changelogs

`--generate-notes` creates notes from merged PRs since the previous release.
To customise the categories and excluded labels, create
`.github/release.yml` in the repository:

```yaml
# .github/release.yml
changelog:
  exclude:
    labels:
      - ignore-for-release
  categories:
    - title: Breaking Changes
      labels:
        - breaking-change
    - title: New Features
      labels:
        - enhancement
    - title: Bug Fixes
      labels:
        - bug
    - title: Other Changes
      labels:
        - "*"
```

Preview the generated notes without creating a release:

```bash
gh api repos/{owner}/{repo}/releases/generate-notes \
  -X POST \
  -f tag_name=v1.3.0 \
  -f previous_tag_name=v1.2.3 \
  --jq '.body'
```

---

## Prerelease Promotion

To promote a prerelease to stable:

```bash
# Mark as no longer a prerelease and publish (undraft)
gh release edit v2.0.0-beta.1 \
  --tag v2.0.0 \
  --prerelease=false \
  --draft=false \
  --title "v2.0.0 — Stable release"
```

If the tag itself needs to change, delete and recreate instead — `gh release
edit` does not rename the git tag.

---

## Attestation

`gh` can verify provenance attestations produced by GitHub Actions:

```bash
# Verify a release asset's attestation
gh attestation verify dist/app-linux-amd64 --repo owner/repo

# Verify and output the attestation bundle as JSON
gh attestation verify dist/app-linux-amd64 --repo owner/repo --format json
```

Attestation is produced by the `attest-build-provenance` action in the release
workflow. See the GitHub docs for the full workflow setup.
