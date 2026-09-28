# Changelog

All notable changes are documented here.

## Unreleased

- Marked the public repository as an alpha test release.
- Added known-issue disclosure for the OpenAI authorization failure and provider/model UI limitations.
- Added contribution and safe bug-reporting guidance.

## 0.2.0 — 2026-09-14

- Reorganised setup and preflight into photographer-friendly Basic, Project details, What to create and Advanced groups.
- Added concise `?` help beside unfamiliar controls and aligned form labels and fields.
- Renamed Learning profile in the main workflow to Project / property name and shows the locally remembered vocabulary count.
- Displays detected immediate and parent folder labels before the user decides whether to enable them as hints.
- Moved the editable prompt, model controls, creativity and request pace under an advanced disclosure, with Restore standard prompt.
- Rebuilt multi-image review as large vertical cards using Lightroom's native `catalog_photo` preview.
- Added Select all metadata and Select none actions and human-readable confidence wording.
- Added optional, review-first Lightroom stars and colour labels: 5/blue Hero, 4/green Portfolio, 3/yellow Supporting, 2/red Needs review, 1/no colour Reject candidate.
- Added a master rating switch plus an independent per-image opt-out; the master starts disabled for new installations.
- Deletes each metadata-free derivative immediately after its provider response instead of retaining it through review.
- Increased the reviewed batch limit from 10 to 50 JPEGs.

## 0.1.6 — 2026-09-14

- Added the complete editable analysis prompt to preflight and remember edits between batches.
- Display the already-rendered metadata-free JPEG derivative as a larger review preview using the SDK-supported file-path value.
- Keep preview derivatives only through review, then delete them after save or cancel; failed analyses delete their derivative immediately.
- Expanded the image area so filenames no longer wrap one character per line.

## 0.1.5 — 2026-09-14

- Pass the live analysis function context to both dialog property tables and explicitly bind each dialog to its table.
- Correct batch row construction so all rows are passed in one child table.
- Pass photo objects directly to the export session and use LrTasks.pcall around rendering/network calls that may yield.
- Keep the v0.1.4 preference-saving fix. Mocked tests do not certify Lightroom integration or cloud API behavior.

## 0.1.4 — 2026-09-14

- Fixed the actual persistence failure: Plug-in Manager endDialog receives no Export-style result argument. The previous guard prevented every preference save.
- Added Save settings with immediate local-key status and explicit binding on the configuration column.
- Blank replacement fields preserve saved keys; surrounding whitespace is trimmed.
- Regression tests exercise callback-only save, button save, reopen, both providers, and blank preservation with a mocked SDK. These are not an in-Lightroom integration test.

## 0.1.3 — 2026-09-14

### Fixed

- Made API-key persistence explicit and safe. Saved keys are never placed back into Lightroom’s masked password field; a status label now confirms whether each key is stored, and leaving a field blank preserves its saved key.

## 0.1.2 — 2026-09-13

### Fixed

- Removed the unsupported `LrImage` SDK import that caused the menu command to stop with “Could not find namespace: LrImage.” Batch review remains fully available in a reliable text-first list view.

## 0.1.1 — 2026-09-13

### Fixed

- Corrected the Lightroom custom-metadata definition key. Version 0.1.0 used `schema`; Lightroom requires `metadataFieldsForPhotos`, which prevented the plug-in from loading.

## 0.1.0 — 2026-09-13

First independent real-life test release.

### Added

- Independent Lightroom plug-in identity, metadata schema, API client and documentation.
- Direct Gemini and OpenAI analysis from Lightroom; no local bridge or Dropbox integration.
- JPEG-only, locally-available source check and metadata-free 1600px derivative export.
- One compact, multi-image batch-review list with title, flat keywords, Format-ready description/alt text and per-image save control.
- Per-project learning profiles that retain only photographer-approved vocabulary locally.
- Optional immediate-folder and parent-folder naming hints, off by default and never sent as full paths.
- Portfolio triage suggestions stored as plug-in metadata, without touching Lightroom star ratings.
- Privacy, security, limitations and contribution documentation.

### Design decisions

- All AI output remains review-first; no result is saved automatically.
- Project context and folder labels may support an official name only when the photographer explicitly provides or approves them and the visible scene matches.
- Portrait/face identification is excluded from the default prompt and intended workflow.
