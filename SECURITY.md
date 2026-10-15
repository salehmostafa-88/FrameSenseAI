# Security and privacy

## Data flow

FrameSense AI renders a temporary JPEG derivative in Lightroom and sends it directly to the selected provider’s HTTPS API. It then deletes the temporary exported file after reading it for the request.

The intended request includes:

- the temporary JPEG pixels;
- the image's filename (not its folder path);
- the photographer-approved Project context;
- unless switched off, the keywords already on each photo, minus purely numeric keywords (job numbers, IDs) and the photo's Creator / Copyright name;
- locally retained approved vocabulary for the active Learning profile; and
- only when explicitly enabled, immediate folder and parent-folder **labels** for the selected image.

It excludes original file paths, folder structures, GPS and embedded export metadata.

## API keys

Keys are entered in Lightroom Plug-in Manager and stored by Lightroom as local plug-in preferences. Use dedicated, budget-limited API keys. Never enter a key in the project-context or folder-hint fields.

## Responsible use

Review every proposed title, caption, alt text and keyword before saving. Do not use the plug-in to identify people or extract personal data. The default prompt forbids name/face recognition, personal-attribute inference and transcription of visible IDs, documents, screens and licence plates.

## Reporting a vulnerability

Do not open a public issue containing credentials, photographs or personal data. Contact the repository owner privately with a minimal reproducible description and redact all secrets.
