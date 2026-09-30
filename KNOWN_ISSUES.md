# Known issues

FrameSense AI is currently an alpha test release. Review this file before installing it on a production Lightroom catalogue.

## OpenAI provider

Earlier alphas returned HTTP 401 because the Authorization header was passed as a plain table instead of the `{ field =, value = }` list Lightroom's `LrHttp.post` expects. This is corrected and covered by a mocked test, but OpenAI has not yet been verified inside Lightroom Classic. Test it on a single copied JPEG first.

## Provider and model controls

Models are chosen from a fixed, provider-specific menu. The model IDs were checked against provider documentation in September 2026. `gemini-3.1-flash-lite` is the least certain ID; use **Check connection** in Plug-in Manager after choosing a model, and report any model it says is unavailable. When providers retire a model, the menu needs a plug-in update.

Plug-in Manager shows one API-key field for the selected provider. Keys for both providers are kept; switching provider shows the other provider's key status.

## Test scope

The repository includes mocked Lua tests for the core modules, preferences and dialogs. The redesigned Plug-in Manager panel, analyse dialog and review cards (fixed point widths, provider-specific model menus in an overlapping view, live counters) have not yet been checked inside Lightroom Classic. They do not replace tests inside Lightroom Classic, network tests with both providers, or review against a backed-up catalogue.

## Reporting problems

Open a GitHub issue with the Lightroom Classic version, operating system, provider, selected model and redacted error text. Never include API keys, private photographs, full local paths or client information.
