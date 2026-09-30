-- Contract simulation of the Plug-in Manager panel: no Lightroom UI or network calls.
-- Resolve the plug-in folder relative to this file so tests run from any directory.
local testDir = (arg and arg[0] or ''):match('^(.*)[/\\]') or '.'
local pluginDir = testDir .. '/../FrameSenseAI.lrplugin/'
package.path = pluginDir .. '?.lua;' .. package.path

-- Earlier alphas stored free-text models; these must migrate to valid menu choices.
local prefs = { geminiModel = 'gemini-3.5-flash', openaiModel = 'gpt-4o-mini' }
local opened, checks = {}, {}
function import(name)
    if name == 'LrPrefs' then return { prefsForPlugin = function() return prefs end } end
    if name == 'LrView' then return { bind = function(key) return key end, share = function(key) return { share = key } end } end
    if name == 'LrBinding' then return { keyEquals = function(key, value) return { key = key, equals = value } end } end
    if name == 'LrDialogs' then return { message = function() end } end
    if name == 'LrHttp' then return {
        openUrlInBrowser = function(url) table.insert(opened, url) end,
        get = function(url) table.insert(checks, url); return '{}', { status = url:find('gpt%-5%.5') and 404 or 200 } end,
    } end
    if name == 'LrTasks' then return { startAsyncTask = function(fn) fn() end, pcall = pcall, sleep = function() end } end
    if name == 'LrFileUtils' then return {} end
    error('Unexpected namespace: ' .. name)
end

local buttons, popups, passwordFields = {}, {}, {}
local factory = setmetatable({}, { __index = function(_, kind)
    return function(_, spec)
        if kind == 'control_spacing' then return 6 end
        assert(spec.width_in_chars == nil, kind .. ' uses width_in_chars; Plug-in Manager needs fixed point widths')
        if kind == 'push_button' then buttons[spec.title] = spec end
        if kind == 'popup_menu' then table.insert(popups, spec) end
        if kind == 'password_field' then table.insert(passwordFields, spec) end
        assert(kind ~= 'edit_field' or spec.value ~= 'geminiModel' and spec.value ~= 'openaiModel', 'model must not be free text')
        assert(kind ~= 'combo_box', 'model must not be free text')
        return spec
    end
end })

-- Property table that fires observers on assignment, like LrBinding's.
local function propertyTable()
    local values, observers = {}, {}
    return setmetatable({}, {
        __index = function(_, key)
            if key == 'addObserver' then return function(_, name, fn) observers[name] = fn end end
            return values[key]
        end,
        __newindex = function(self, key, value)
            local changed = values[key] ~= value
            values[key] = value
            if changed and observers[key] then observers[key](self, key, value) end
        end,
    })
end

local provider = require 'PluginInfo'
local p = propertyTable()
local sections = provider.sectionsForTopOfDialog(factory, p)
assert(sections[1][1].bind_to_object == p)
assert(prefs.openaiModel == 'gpt-5.4-mini', 'unknown free-text model should migrate to the recommended model')
assert(p.geminiModel == 'gemini-3.5-flash' and p.openaiModel == 'gpt-5.4-mini')
assert(#passwordFields == 1, 'only the selected provider key field should exist')
local modelPopups = 0
for _, popup in ipairs(popups) do
    if popup.value == 'geminiModel' or popup.value == 'openaiModel' then
        modelPopups = modelPopups + 1
        assert(popup.visible and popup.visible.key == 'provider', 'model menu must follow the provider')
        assert(#popup.items >= 3 and popup.items[1].title:find('Economy', 1, true), 'menu should offer cost tiers')
    end
end
assert(modelPopups == 2)
assert(p.readiness:find('Not ready', 1, true) and p.keyStatus:find('No Gemini API key', 1, true))

-- Save a Gemini key; Plug-in Manager's endDialog receives only the property table.
p.newApiKey = '  fake-gemini-test-only  '
provider.endDialog(p)
assert(prefs.geminiApiKey == 'fake-gemini-test-only' and p.newApiKey == '')
assert(p.keyStatus:find('saved', 1, true) and p.readiness:find('Ready: Google Gemini, Gemini 3.5 Flash', 1, true))

-- A key typed, then provider switched before saving, stays with the provider it was typed for.
p.newApiKey = 'typed-for-gemini'
p.provider = 'openai'
assert(prefs.geminiApiKey == 'typed-for-gemini' and prefs.openaiApiKey == nil)
assert(prefs.provider == 'openai' and p.keyStatus:find('No OpenAI API key', 1, true))
p.newApiKey = 'fake-openai-test-only'
buttons['Save'].action()
assert(prefs.openaiApiKey == 'fake-openai-test-only' and prefs.geminiApiKey == 'typed-for-gemini')

-- Blank field keeps the saved key.
p.newApiKey = '   '
provider.endDialog(p)
assert(prefs.openaiApiKey == 'fake-openai-test-only')

-- Model menu choice is saved immediately and Check connection reports on it.
p.openaiModel = 'gpt-5.4-nano'
assert(prefs.openaiModel == 'gpt-5.4-nano')
buttons['Check connection'].action()
assert(checks[#checks]:find('/v1/models/gpt-5.4-nano', 1, true) and p.connectionStatus:find('✓ Connected', 1, true))
p.openaiModel = 'gpt-5.5'
assert(p.connectionStatus == '', 'changing model clears an outdated connection result')
buttons['Check connection'].action()
assert(p.connectionStatus:find('not available', 1, true))

buttons['Get a key…'].action()
assert(opened[#opened] == 'https://platform.openai.com/api-keys')

-- Reopen: field blank, status reflects saved keys.
local reopened = propertyTable()
provider.sectionsForTopOfDialog(factory, reopened)
assert(reopened.newApiKey == '' and reopened.provider == 'openai' and reopened.keyStatus:find('saved', 1, true))
print('PASS: fixed model menus with cost tiers, free-text migration, one key field following provider, key kept with its provider on switch, blank preservation, readiness, check connection, get-a-key link, point widths')
