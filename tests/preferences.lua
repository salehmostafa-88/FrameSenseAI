-- Resolve the plug-in folder relative to this file so tests run from any directory.
local testDir = (arg and arg[0] or ''):match('^(.*)[/\\]') or '.'
local pluginDir = testDir .. '/../FrameSenseAI.lrplugin/'
package.path = pluginDir .. '?.lua;' .. package.path
local prefs = {}
function import(name)
    if name == 'LrPrefs' then return { prefsForPlugin = function() return prefs end } end
    if name == 'LrView' then return { bind = function(key) return key end } end
    if name == 'LrBinding' then return { keyEquals = function(key, value) return { key = key, equals = value } end } end
    if name == 'LrDialogs' then return { message = function() end } end
    error('Unexpected namespace: ' .. name)
end
local buttons = {}
local factory = setmetatable({}, { __index = function(_, kind)
    return function(_, spec)
        if kind == 'control_spacing' then return 6 end
        if kind == 'push_button' and spec.title == 'Save settings' then buttons[#buttons + 1] = spec end
        return spec
    end
end })
local provider = require 'PluginInfo'
local p = {}
local sections = provider.sectionsForTopOfDialog(factory, p)
assert(sections[1][1].bind_to_object == p)
assert(p.geminiModel == 'gemini-3.5-flash' and p.openaiModel == 'gpt-4o-mini')
p.newGeminiApiKey = '  fake-gemini-test-only  '
p.newOpenaiApiKey = 'fake-openai-test-only'
provider.endDialog(p) -- Exact one-argument Plug-in Manager contract.
assert(prefs.geminiApiKey == 'fake-gemini-test-only')
assert(prefs.openaiApiKey == 'fake-openai-test-only')
local reopened = {}
provider.sectionsForTopOfDialog(factory, reopened)
assert(reopened.newGeminiApiKey == '')
assert(reopened.geminiKeyStatus:find('Saved', 1, true))
provider.endDialog(reopened)
assert(prefs.geminiApiKey == 'fake-gemini-test-only')
assert(prefs.openaiApiKey == 'fake-openai-test-only')
reopened.newGeminiApiKey = 'new-fake-test-key'
reopened.provider = 'openai'
buttons[#buttons].action()
assert(prefs.geminiApiKey == 'new-fake-test-key')
assert(prefs.provider == 'openai')
assert(reopened.geminiKeyStatus:find('Saved locally', 1, true))
reopened.newGeminiApiKey = '   '
provider.endDialog(reopened)
assert(prefs.geminiApiKey == 'new-fake-test-key')
print('PASS: bindings, single-argument callback, both keys, reopen, blank preservation, explicit save, whitespace')
