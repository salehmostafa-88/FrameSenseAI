# Changelog

All notable changes are documented here.

## Unreleased

- Marked the public repository as an alpha test release.
- Added known-issue disclosure for the OpenAI authorization failure and provider/model UI limitations.
- Added contribution and safe bug-reporting guidance.

### Fixed

- Keywords that already existed in the Lightroom catalogue were silently not applied: `createKeyword` now asks for the existing keyword, and each keyword is looked up once per batch.
- OpenAI requests now send the `Authorization` header in the `{ field, value }` form `LrHttp.post` requires (the cause of the HTTP 401). Needs confirmation inside Lightroom Classic.
- A blank title or description in review no longer overwrites the existing catalogue title or caption.
- A generic immediate folder name such as `Finals` no longer hides a useful parent-folder hint.
- Descriptions are shortened by characters rather than bytes, at a word boundary, without splitting accented characters, and stay within 255 characters including the ellipsis.
- Emoji and control characters now survive the JSON reader and writer.
- Network failures report the error instead of stopping with a Lua comparison error.
- The mocked tests no longer depend on the repository folder being named `framesense-ai-lightroom`.

### Title, caption and alt text

- Title, caption and alt text are now three separate fields with separate jobs: a website title line (`Space - Property, City, Country`), a ready-to-post caption and a descriptive alt text for search engines. Each can be turned on or off under What to create, and each has its own live character counter in the review.
- Alt text is written to Lightroom's native **Alt Text** field (IPTC accessibility, Lightroom Classic 13.2+) as well as the FrameSense metadata field. If Lightroom refuses the field, the save still completes and a single notice explains where the alt text went.
- Each photo's existing keywords are sent as confirmed facts (on by default, with an opt-out) so the AI can use the property, brand and location names. Purely numeric keywords and the photographer's own Creator / Copyright name are filtered out first.
- Suggested keywords that are already on the photo are removed; the review lists the existing keywords for reference.
- The prompt is split into editable guidance and fixed output rules the plug-in always appends, so a customised prompt cannot merge the three fields again. An unchanged copy of the old standard prompt upgrades automatically; customised prompts are kept.
- The "Description / alt text" choice becomes separate Caption and Alt text choices, migrated from the previous setting.

### Interface redesign

- Model fields are fixed menus, never free text, labelled by cost tier with an approximate cost per 100 photos: Gemini 3.1 Flash-Lite / 3.5 Flash / 3.1 Pro, and OpenAI GPT-5.4 nano / mini / GPT-5.4 / GPT-5.5. The `?` beside each menu lists prices per 1M tokens.
- Saved free-text models from earlier alphas migrate to the recommended model when not in the menu.
- The provider menu now drives the panel: only the selected provider's model menu and API-key field are shown. A key typed before switching provider is kept with the provider it was typed for.
- Plug-in Manager: key status moved under the field so it is never cut off; Save, **Check connection** (a free call that validates the key and model access) and **Get a key…** buttons; a Ready / Not ready line.
- All dialogs use fixed point widths instead of `width_in_chars`, which rendered roughly twice as wide as intended and pushed controls out of Plug-in Manager's frame.
- Analyse dialog: the model choice for the batch is at the top with a key warning; plainer labels (Confirmed facts, Keywords for every photo); creativity and pause settings live only in Plug-in Manager; the Advanced section now holds only the prompt. A missing key or an empty What to create stops before anything is uploaded, keeping your edits.
- Review cards show only the fields chosen under What to create, with a shorter toolbar (Select all, Select none, live count, Also set Lightroom stars & colour labels) and Save / Discard… buttons.

### Changed

- RAW, non-JPEG and offline files in a selection are listed and skipped with consent instead of blocking the whole batch; selections above 50 offer to continue with the first 50.
- Review dialog: sized to fit the screen so its buttons stay visible on laptops, live "n of N selected" count, live 255-character counter for the description, AI cautions shown next to the rating, per-image rating checkbox follows the master switch, and Cancel asks before discarding paid-for results.
- Model fields are provider-specific combo boxes with suggested model IDs; any other ID can still be typed.
- Creativity shows a readable two-decimal value; Request pace is a numeric field.
- Preflight labels are consistently right-aligned; the learning-profile summary updates as you type the project name.
- Rate-limited and temporarily unavailable provider responses (429, 5xx) are retried twice with back-off; requests use a 120-second timeout.
- Temperature is omitted for OpenAI GPT-5 and o-series models, which reject custom values.
- Gemini "thought" parts are ignored and a blocked/empty response reports its finish reason.
- Approved vocabulary is only remembered when keyword saving is enabled.
- Added `tests/core.lua` for JSON, text helpers, the provider request contract and learning profiles.

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
