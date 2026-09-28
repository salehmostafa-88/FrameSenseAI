# Contributing

FrameSense AI is an early Lightroom Classic plug-in. Small, reviewable changes with a clear Lightroom workflow benefit are preferred.

## Before opening a change

1. Check the existing issues and `KNOWN_ISSUES.md`.
2. Do not commit API keys, exported client photographs, catalogue files, logs containing paths, or provider responses containing private data.
3. Keep AI output review-first. New features must not silently write metadata, ratings or labels.
4. Preserve the privacy boundary: temporary resized JPEG derivatives only, with export metadata disabled.
5. Document user-facing changes in `CHANGELOG.md`.

## Testing

Run the mocked tests when a compatible Lua runtime is available:

```sh
lua tests/preferences.lua
lua tests/dialogs.lua
```

Also test the plug-in inside a supported Lightroom Classic version using copied JPEGs and a backed-up catalogue. State exactly which provider, model, Lightroom version and operating system were tested.

## Bug reports

Include reproducible steps and redacted error text. Do not post credentials, client images, personal information, GPS data or private filesystem paths.
