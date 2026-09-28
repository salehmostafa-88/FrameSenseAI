# Known issues

FrameSense AI is currently an alpha test release. Review this file before installing it on a production Lightroom catalogue.

## OpenAI provider

The current OpenAI request path can return HTTP 401 because its Authorization header is not reliably passed in the format expected by Lightroom's `LrHttp.post` API. Treat OpenAI support as unavailable until the header handling is corrected and verified inside Lightroom Classic.

## Provider and model controls

The configuration and preflight interfaces currently expose model fields as free text and do not fully adapt them to the selected provider. A future alpha will replace these fields with provider-specific model menus and show only the relevant API-key controls.

## Test scope

The repository includes mocked Lua contract tests for preferences and dialogs. They do not replace tests inside Lightroom Classic, network tests with both providers, or review against a backed-up catalogue.

## Reporting problems

Open a GitHub issue with the Lightroom Classic version, operating system, provider, selected model and redacted error text. Never include API keys, private photographs, full local paths or client information.
