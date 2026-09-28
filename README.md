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
- Original file paths, GPS, existing Lightroom keywords and folder structures are not transmitted.
- **Folder-name hints are off by default.** If enabled, the plug-in derives only the immediate folder and parent-folder labels for each selected photo. Full paths are never sent.
- A folder label is treated as optional photographer-provided context; the model is instructed to use it only when it matches the visible scene.
- No local bridge, Dropbox connection, local web server or catalogue-wide index is used.
- Learning profiles retain approved keyword vocabulary locally in Lightroom plug-in preferences. They are not cloud fine-tuning.

Cloud providers process the derivative under your own provider account and terms. Do not submit photos containing identifiable people, personal documents, screens, IDs or vehicle plates unless you are comfortable transmitting the visible pixels to that provider.

## Requirements

- Adobe Lightroom Classic with SDK 11.0 support (Lightroom Classic 11 / 2022 or later)
- A Google AI Studio Gemini API key or an OpenAI API key
- JPEG source files available locally on disk

The plug-in deliberately rejects RAW and non-JPEG files. For Dropbox Smart Sync, make the final JPEGs offline before analysis. Lightroom/Dropbox decide availability; the plug-in does not request Dropbox access or hydrate files deliberately.

## Installation

1. Download the release ZIP and unzip it somewhere stable on your Mac or PC.
2. In Lightroom Classic, open **File → Plug-in Manager → Add**.
3. Select the included `FrameSenseAI.lrplugin` folder.
4. Choose **FrameSense AI** in Plug-in Manager and enter the API key for the provider you intend to use.
5. Start with one to three JPEGs.

Do not put your API key in project context, filenames or prompts. Set a provider budget limit independently in Google AI Studio or OpenAI.

## Workflow

1. Select up to fifty locally available JPEGs in Library.
2. Choose **Library → Plug-in Extras → Analyze selected JPEGs with FrameSense AI**.
3. In the simplified Project details group, set:
   - **Project / property name** — a stable name for one property or project, for example `Mövenpick Resort Taba`. This is also the local learning-profile name.
   - **Project context** — confirmed facts you explicitly want to make available, such as property name, location, design intent or official room names.
   - **Shared project tags** — optional terms to add to each saved image.
   - **Folder-name hints** — enable only when the displayed labels are useful and intentional, for example `AlFresco Restaurant`.
4. Review the compact list. Edit inaccurate title, keywords or Format description. Untick any image you do not want saved.

The complete analysis prompt, model, creativity and request pace are grouped under **Show advanced settings**. You can edit the prompt and restore the standard version. Batch review uses Lightroom's own catalogue-photo preview; the temporary metadata-free derivative is deleted immediately after analysis.
5. Adjust the portfolio suggestion when your editorial judgement differs. If **Apply Lightroom ratings & labels** is enabled, FrameSense can also write the reviewed score and mapped colour to Lightroom. The master option is off initially and every image has its own opt-out.
6. Save selected rows.

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
- OpenAI support in the current alpha has a known authorization-header defect and should not be relied on until it is fixed and tested in Lightroom. The provider/model interface also needs to become provider-specific.

See [KNOWN_ISSUES.md](KNOWN_ISSUES.md) for the current test status.

## Credits and independence

FrameSense AI is an independent implementation created from the functional requirements of a professional hospitality-photography workflow. It does **not** include LrGeniusTagAI source code, branding, plug-in identifier, update mechanism or documentation.

The project acknowledges the early workflow research that led to evaluating [LrGeniusTagAI](https://github.com/LrGenius/LrGeniusTagAI). FrameSense AI is not affiliated with, endorsed by or an official release of LrGeniusTagAI.

See [CREDITS.md](CREDITS.md), [SECURITY.md](SECURITY.md), [CONTRIBUTING.md](CONTRIBUTING.md), [KNOWN_ISSUES.md](KNOWN_ISSUES.md) and [CHANGELOG.md](CHANGELOG.md).

## Licence

FrameSense AI source in this repository is released under the [MIT License](LICENSE).
