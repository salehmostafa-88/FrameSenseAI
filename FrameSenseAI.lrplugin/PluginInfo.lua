local LrBinding = import 'LrBinding'
local LrDialogs = import 'LrDialogs'
local LrPrefs = import 'LrPrefs'
local LrView = import 'LrView'
local Defaults = require 'Defaults'

local prefs = LrPrefs.prefsForPlugin()
Defaults.initialize(prefs)
local Provider = {}

local function trim(value) return (tostring(value or ''):gsub('^%s*(.-)%s*$', '%1')) end
local function help(title, message) return function() LrDialogs.message(title, message, 'info') end end
local function statusFor(key) return key and key ~= '' and 'Saved locally — leave blank to keep it' or 'No key saved' end

local function saveSettings(propertyTable)
    prefs.provider = propertyTable.provider
    prefs.geminiModel = trim(propertyTable.geminiModel)
    prefs.openaiModel = trim(propertyTable.openaiModel)
    for _, provider in ipairs { 'gemini', 'openai' } do
        local input = provider == 'gemini' and 'newGeminiApiKey' or 'newOpenaiApiKey'
        local key = trim(propertyTable[input])
        if key ~= '' then prefs[provider .. 'ApiKey'] = key end
        propertyTable[input] = ''
        propertyTable[provider .. 'KeyStatus'] = statusFor(prefs[provider .. 'ApiKey'])
    end
    prefs.temperature = math.max(0, math.min(1, tonumber(propertyTable.temperature) or 0.2))
    prefs.batchDelayMs = math.max(0, math.min(10000, tonumber(propertyTable.batchDelayMs) or 700))
end

function Provider.sectionsForTopOfDialog(f, propertyTable)
    local bind = LrView.bind
    propertyTable.provider, propertyTable.geminiModel, propertyTable.openaiModel = prefs.provider, prefs.geminiModel, prefs.openaiModel
    propertyTable.newGeminiApiKey, propertyTable.newOpenaiApiKey = '', ''
    propertyTable.geminiKeyStatus, propertyTable.openaiKeyStatus = statusFor(prefs.geminiApiKey), statusFor(prefs.openaiApiKey)
    propertyTable.temperature, propertyTable.batchDelayMs = prefs.temperature, prefs.batchDelayMs
    local labelWidth, fieldWidth = 20, 38
    local function question(title, message) return f:push_button { title = '?', width = 24, action = help(title, message) } end
    local function modelChoices(provider)
        local choices = {}
        for _, model in ipairs(Defaults.models) do
            if model.provider == provider then table.insert(choices, model.value) end
        end
        return choices
    end

    return {{
        title = 'FrameSense AI — settings', bind_to_object = propertyTable,
        f:column {
            bind_to_object = propertyTable, spacing = f:control_spacing(),
            f:static_text { title = 'Connect your AI provider once. Blank API-key fields keep the key already saved in Lightroom preferences.' },
            f:group_box { title = 'Basic setup',
                f:column { spacing = f:control_spacing(),
                    f:row {
                        f:static_text { title = 'AI provider', width_in_chars = labelWidth },
                        f:popup_menu { value = bind 'provider', width_in_chars = fieldWidth, items = {
                            { title = 'Google Gemini', value = 'gemini' }, { title = 'OpenAI', value = 'openai' },
                        } },
                        question('AI provider', 'Choose the provider account FrameSense should use. A ChatGPT subscription is separate from OpenAI API billing.'),
                    },
                    f:row {
                        f:static_text { title = 'Gemini API key', width_in_chars = labelWidth },
                        f:password_field { value = bind 'newGeminiApiKey', width_in_chars = fieldWidth },
                        f:static_text { title = bind 'geminiKeyStatus', width_in_chars = 34 },
                        question('Gemini API key', 'Paste a replacement key here, then choose Save settings. Leave it blank to keep the saved key.'),
                    },
                    f:row {
                        f:static_text { title = 'OpenAI API key', width_in_chars = labelWidth },
                        f:password_field { value = bind 'newOpenaiApiKey', width_in_chars = fieldWidth },
                        f:static_text { title = bind 'openaiKeyStatus', width_in_chars = 34 },
                        question('OpenAI API key', 'Paste a replacement key here, then choose Save settings. Leave it blank to keep the saved key.'),
                    },
                    f:push_button { title = 'Save settings', action = function() saveSettings(propertyTable) end },
                },
            },
            f:group_box { title = 'Advanced settings',
                f:column { spacing = f:control_spacing(),
                    f:row {
                        f:static_text { title = 'Model', width_in_chars = labelWidth },
                        f:view { place = 'overlapping',
                            f:combo_box { value = bind 'geminiModel', items = modelChoices('gemini'), width_in_chars = fieldWidth, visible = LrBinding.keyEquals('provider', 'gemini') },
                            f:combo_box { value = bind 'openaiModel', items = modelChoices('openai'), width_in_chars = fieldWidth, visible = LrBinding.keyEquals('provider', 'openai') },
                        },
                        question('Model', 'Shows the model for the selected AI provider. Pick a suggestion or type any model ID your provider account supports.'),
                    },
                    f:row {
                        f:static_text { title = 'Default creativity', width_in_chars = labelWidth },
                        f:slider { value = bind 'temperature', min = 0, max = 1, integral = false, width_in_chars = 24 },
                        f:static_text { title = bind { key = 'temperature', transform = function(value) return string.format('%.2f', tonumber(value) or 0) end }, width_in_chars = 5 },
                        question('Creativity', 'Lower values favour consistent factual wording. Higher values allow more variation but may require more correction.'),
                    },
                    f:row {
                        f:static_text { title = 'Request pace (ms)', width_in_chars = labelWidth },
                        f:edit_field { value = bind 'batchDelayMs', min = 0, max = 10000, precision = 0, width_in_chars = 10 },
                        question('Request pace', 'Pause between photos. Increase this if your provider reports rate-limit errors.'),
                    },
                },
            },
            f:static_text { title = 'Ready when the selected provider has a saved key. Keys are stored locally in this Lightroom plug-in preference set.' },
        },
    }}
end

function Provider.endDialog(propertyTable) saveSettings(propertyTable) end
return Provider
