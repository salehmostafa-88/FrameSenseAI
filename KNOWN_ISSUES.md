# Known issues

FrameSense AI is currently an alpha test release. Review this file before installing it on a production Lightroom catalogue.

## OpenAI provider

Earlier alphas returned HTTP 401 because the Authorization header was passed as a plain table instead of the `{ field =, value = }` list Lightroom's `LrHttp.post` expects. This is corrected and covered by a mocked test, but OpenAI has not yet been verified inside Lightroom Classic. Test it on a single copied JPEG first.

## Provider and model controls

Model fields are now provider-specific combo boxes with suggested IDs. Both API-key fields remain visible in Plug-in Manager so you can keep a key for each provider. The suggested model list is a convenience only; check your provider's current model catalogue.

## Test scope

The repository includes mocked Lua tests for the core modules, preferences and dialogs. The new review-dialog layout (screen-fitted size, overlapping provider-specific model boxes, live counters) has not yet been checked inside Lightroom Classic. They do not replace tests inside Lightroom Classic, network tests with both providers, or review against a backed-up catalogue.

## Reporting problems

Open a GitHub issue with the Lightroom Classic version, operating system, provider, selected model and redacted error text. Never include API keys, private photographs, full local paths or client information.
