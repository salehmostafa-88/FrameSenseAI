# FrameSense AI for Lightroom Classic

FrameSense AI is a **review-first metadata assistant** for professional hospitality, interior and architectural photography. It creates useful, frame-specific Lightroom metadata—not generic project boilerplate—and lets the photographer correct every selected image before anything is written to the catalogue.

It is designed around one practical job: make a professional image archive easier to find, present and reuse without surrendering editorial judgement to an AI model.

> **Status: alpha / real-life test release.** Use it on copies or a small, backed-up selection first. Gemini is the currently tested provider; see [KNOWN_ISSUES.md](KNOWN_ISSUES.md) before using OpenAI.

## What it does

For 1–50 selected, locally available JPEGs, FrameSense AI:

1. Renders a temporary 1600px JPEG derivative with export metadata disabled.
2. Sends that derivative directly to your selected Gemini or OpenAI API account.
3. Proposes a title, 6–12 flat keywords, a factual caption/Format image description, a confidence indicator and a portfolio-usefulness suggestion.
4. Presents all results in one scrollable multi-image review list.
5. Saves only the rows you approve, then remembers the approved vocabulary under the named learning profile on your own Mac.

It does not scan your catalogue, connect to Dropbox, process RAW files, or silently apply AI results. Lightroom stars and colour labels change only when you enable the master rating option and leave the individual image enabled.

## Built for this work

Hospitality, interiors and architecture are the primary use cases. The default prompt prioritises room/scene type, materials, furniture, F&B/service details, lighting, viewpoint and composition that are visibly specific to the individual frame.

The first keyword is intended to be a useful primary visible category, such as `hotel guest room`, `restaurant interior`, `bar interior`, `hotel lobby`, `pool area`, `architecture exterior`, `architectural detail` or `landscape architecture`.

The plug-in also supports non-portrait food, product, landscape, cityscape, vehicle, wildlife, document/artwork and abstract images. Lightroom’s own People tools remain the appropriate local tool for faces and portrait organisation.

## Privacy and data sent

- Only a temporary, resized JPEG derivative is transmitted to Gemini or OpenAI.
- The code requests an export with metadata disabled and location metadata removed.
- The image's filename is included as context. Original file paths, GPS, existing Lightroom keywords and folder structures are not transmitted.
- **Folder-name hints are off by default.** If enabled, the plug-in derives only the immediate folder and parent-folder labels for each selected photo. Full paths are never sent.
- A folder label is treated as optional photographer-provided context; the model is instructed to use it only when it matches the visible scene.
- No local bridge, Dropbox connection, local web server or catalogue-wide index is used.
- Learning profiles retain approved keyword vocabulary locally in Lightroom plug-in preferences. They are not cloud fine-tuning.

Cloud providers process the derivative under your own provider account and terms. Do not submit photos containing identifiable people, personal documents, screens, IDs or vehicle plates unless you are comfortable transmitting the visible pixels to that provider.

## Requirements

- Adobe Lightroom Classic with SDK 11.0 support (Lightroom Classic 11 / 2022 or later)
- A Google AI Studio Gemini API key or an OpenAI API key
- JPEG source files available locally on disk

The plug-in deliberately skips RAW and non-JPEG files: if a selection contains them, it lists them and offers to continue with the JPEGs only. For Dropbox Smart Sync, make the final JPEGs offline before analysis. Lightroom/Dropbox decide availability; the plug-in does not request Dropbox access or hydrate files deliberately.

## Installation

1. Download the release ZIP and unzip it somewhere stable on your Mac or PC.
2. In Lightroom Classic, open **File → Plug-in Manager → Add**.
3. Select the included `FrameSenseAI.lrplugin` folder.
4. Choose **FrameSense AI** in Plug-in Manager, pick the **AI provider** and **Model**, paste that provider's API key (or use **Get a key…**), then choose **Save** and **Check connection**. The check is free: it confirms the key and that it can use the chosen model without sending a photo.
5. Start with one to three JPEGs.

## Choosing a model

Models are chosen from a fixed menu, labelled by what they cost, so no model ID has to be typed:

| Provider | Tier | Model | US$ per 1M tokens (in / out) | Rough cost per 100 photos |
|---|---|---|---|---:|
| Gemini | Economy | Gemini 3.1 Flash-Lite | 0.25 / 1.50 | ~$0.20 |
| Gemini | Recommended | Gemini 3.5 Flash | 1.50 / 9.00 | ~$1.20 |
| Gemini | Premium | Gemini 3.1 Pro (preview) | 2.00 / 12.00 | ~$1.60 |
| OpenAI | Economy | GPT-5.4 nano | 0.20 / 1.25 | ~$0.17 |
| OpenAI | Recommended | GPT-5.4 mini | 0.75 / 4.50 | ~$0.60 |
| OpenAI | Standard | GPT-5.4 | 2.50 / 15.00 | ~$2.00 |
| OpenAI | Premium | GPT-5.5 | 5.00 / 30.00 | ~$4.00 |

Prices were checked in September 2026. The per-100 estimate assumes roughly 2,000 input and 1,000 output tokens per photo; models that "think" can use more. Your provider's dashboard is the authoritative source.

Do not put your API key in project context, filenames or prompts. Set a provider budget limit independently in Google AI Studio or OpenAI.

## Workflow

1. Select up to fifty locally available JPEGs in Library.
2. Choose **Library → Plug-in Extras → Analyze selected JPEGs with FrameSense AI**.
3. In **AI model for this batch**, keep or change the provider and model. A warning shows if that provider has no saved key.
4. In **Project details**, set:
   - **Project / property name** — a stable name for one property or project, for example `Mövenpick Resort Taba`. Approved keywords are remembered under this name.
   - **Confirmed facts** — facts you explicitly want used, such as property name, location, design intent or official room names.
   - **Keywords for every photo** — optional terms added to each saved image.
   - **Folder names** — tick only when the displayed labels are useful, for example `AlFresco Restaurant`.
5. Under **What to create**, tick the fields you want. The review shows only those fields.
6. Review each photo card. Correct the title, keywords or description (a counter shows the 255-character limit) and untick any photo you do not want saved.
7. Adjust the portfolio rating where your judgement differs. **Also set Lightroom stars & colour labels** is off initially, and every photo has its own opt-out.
8. Choose **Save**. **Discard…** asks before throwing away results you have already paid for.

**Show analysis prompt** reveals the full prompt for editing, with **Restore standard prompt**. Creativity and the pause between photos are in Plug-in Manager under **Advanced (optional)**. The temporary copy sent to the provider is deleted immediately after analysis.

## Learning profiles

The learning profile is deliberately modest and controllable. After you save reviewed rows, FrameSense AI retains the approved flat keyword vocabulary for that named profile. On later runs using the same profile, it supplies that vocabulary to the model as a preference—only when it matches the image.

It is not self-training, provider fine-tuning, or a catalogue scan. Rename the profile to begin a clean vocabulary for another property or project.

## Portfolio triage

Each result receives a suggested score:

| Score | Label | Typical role |
|---:|---|---|
| 5 | Hero | Main cover / strongest campaign image |
| 4 | Portfolio | Key portfolio or gallery image |
| 3 | Supporting | Useful gallery coverage |
| 2 | Needs review | Needs human decision or is more situational |
| 1 | Reject candidate | Do not prioritise for portfolio use |

Optional Lightroom mapping: 5 stars + blue, 4 stars + green, 3 stars + yellow, 2 stars + red, and 1 star + no colour. The plug-in writes Lightroom's native colour field, so customised label-set names do not break the mapping.

It is a visual selection aid based on the derivative’s composition, clarity of purpose, lighting/readability, styling and uniqueness. It cannot judge full-resolution focus, retouching, legal clearances or whether a photo fulfils a client’s specific shot-list requirement.

## Providers and costs

FrameSense AI calls the provider directly from Lightroom:

- **Gemini** uses Google AI Studio credentials.
- **OpenAI** uses an OpenAI API key; a ChatGPT subscription alone is not an API billing account.

Usage and prices are controlled by the provider and model. Treat provider dashboards as the authoritative source for cost.

## Limitations

- AI output is a proposal. Review all content before publication, delivery or adding it to client-facing channels.
- Folder labels and project context can be wrong, stale or too broad. Only give it confirmed facts.
- The local-file check is intentionally conservative but cannot prove Dropbox will never need to download a source file.
- The initial release supports English output and direct Gemini/OpenAI APIs.
- The OpenAI authorization-header defect is fixed in code but not yet verified inside Lightroom; test it on a single copied JPEG first.

See [KNOWN_ISSUES.md](KNOWN_ISSUES.md) for the current test status.

## Credits and independence

FrameSense AI is an independent implementation created from the functional requirements of a professional hospitality-photography workflow. It does **not** include LrGeniusTagAI source code, branding, plug-in identifier, update mechanism or documentation.

The project acknowledges the early workflow research that led to evaluating [LrGeniusTagAI](https://github.com/LrGenius/LrGeniusTagAI). FrameSense AI is not affiliated with, endorsed by or an official release of LrGeniusTagAI.

See [CREDITS.md](CREDITS.md), [SECURITY.md](SECURITY.md), [CONTRIBUTING.md](CONTRIBUTING.md), [KNOWN_ISSUES.md](KNOWN_ISSUES.md) and [CHANGELOG.md](CHANGELOG.md).

## Licence

FrameSense AI source in this repository is released under the [MIT License](LICENSE).
