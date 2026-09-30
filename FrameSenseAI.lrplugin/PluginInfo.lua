local LrBinding = import 'LrBinding'
local LrDialogs = import 'LrDialogs'
local LrHttp = import 'LrHttp'
local LrPrefs = import 'LrPrefs'
local LrTasks = import 'LrTasks'
local LrView = import 'LrView'
local Defaults = require 'Defaults'
local ProviderClient = require 'ProviderClient'

local prefs = LrPrefs.prefsForPlugin()
Defaults.initialize(prefs)
local Provider = {}

-- Plug-in Manager's panel is only about 600 points wide, so every width is fixed in points.
local fieldWidth = 330

local function trim(value) return (tostring(value or ''):gsub('^%s*(.-)%s*$', '%1')) end
local function help(title, message) return function() LrDialogs.message(title, message, 'info') end end

local function keyStatus(provider)
    local info = Defaults.providerInfo[provider]
    if trim(prefs[provider .. 'ApiKey']) ~= '' then return '✓ ' .. info.keyName .. ' saved. Leave the field blank to keep it.' end
    return 'No ' .. info.keyName .. ' saved yet. Paste it above, then choose Save.'
end

local function readiness(provider)
    local info = Defaults.providerInfo[provider]
    local model = Defaults.modelInfo(provider, prefs[provider .. 'Model'])
    if trim(prefs[provider .. 'ApiKey']) == '' then return 'Not ready: add a ' .. info.keyName .. ' to analyse photos with ' .. info.name .. '.' end
    return 'Ready: ' .. info.name .. ', ' .. (model and model.name or '') .. '.'
end

-- Stores a typed key under the provider it was typed for, then clears the field.
local function storeTypedKey(propertyTable, provider)
    local key = trim(propertyTable.newApiKey)
    if key ~= '' then prefs[provider .. 'ApiKey'] = key end
    propertyTable.newApiKey = ''
end

local function refreshStatus(propertyTable)
    propertyTable.keyStatus = keyStatus(propertyTable.provider)
    propertyTable.readiness = readiness(propertyTable.provider)
end

local function saveSettings(propertyTable)
    prefs.provider = propertyTable.provider
    prefs.geminiModel = propertyTable.geminiModel
    prefs.openaiModel = propertyTable.openaiModel
    storeTypedKey(propertyTable, propertyTable.provider)
    prefs.temperature = math.max(0, math.min(1, tonumber(propertyTable.temperature) or 0.2))
    prefs.batchDelayMs = math.max(0, math.min(10000, tonumber(propertyTable.batchDelayMs) or 700))
    refreshStatus(propertyTable)
end

function Provider.sectionsForTopOfDialog(f, propertyTable)
    local bind, share = LrView.bind, LrView.share
    propertyTable.provider, propertyTable.geminiModel, propertyTable.openaiModel = prefs.provider, prefs.geminiModel, prefs.openaiModel
    propertyTable.newApiKey = ''
    propertyTable.temperature, propertyTable.batchDelayMs = prefs.temperature, prefs.batchDelayMs
    propertyTable.connectionStatus = ''
    refreshStatus(propertyTable)

    -- Switching provider keeps a half-typed key with the provider it was typed for.
    local currentProvider = propertyTable.provider
    propertyTable:addObserver('provider', function()
        storeTypedKey(propertyTable, currentProvider)
        currentProvider = propertyTable.provider
        prefs.provider = currentProvider
        propertyTable.connectionStatus = ''
        refreshStatus(propertyTable)
    end)
    for _, key in ipairs { 'geminiModel', 'openaiModel' } do
        propertyTable:addObserver(key, function()
            prefs[key] = propertyTable[key]
            propertyTable.connectionStatus = ''
            refreshStatus(propertyTable)
        end)
    end

    local function label(title) return f:static_text { title = title, alignment = 'right', width = share 'fsLabel' } end
    local function question(title, message) return f:push_button { title = '?', width = 24, action = help(title, message) } end
    local function indented(view) return f:row { f:static_text { title = '', width = share 'fsLabel' }, view } end
    local function checkConnection()
        saveSettings(propertyTable)
        propertyTable.connectionStatus = 'Checking…'
        LrTasks.startAsyncTask(function()
            local provider = propertyTable.provider
            -- LrTasks.pcall prepends its own success flag to checkConnection's (ok, message).
            local ran, okOrError, message = LrTasks.pcall(ProviderClient.checkConnection, provider, prefs[provider .. 'ApiKey'], prefs[provider .. 'Model'])
            propertyTable.connectionStatus = ran and message or ('✗ ' .. tostring(okOrError))
        end)
    end

    return {{
        title = 'FrameSense AI — settings', bind_to_object = propertyTable,
        f:column {
            bind_to_object = propertyTable, spacing = f:control_spacing(),
            f:group_box { title = 'AI provider and model', fill_horizontal = 1,
                f:column { spacing = f:control_spacing(),
                    f:row {
                        label('AI provider'),
                        f:popup_menu { value = bind 'provider', items = Defaults.providers, width = fieldWidth },
                        question('AI provider', 'The provider account that analyses your photos and bills you. Only the key and models for the selected provider are shown.\n\nA ChatGPT subscription is separate from OpenAI API billing.'),
                    },
                    f:row {
                        label('Model'),
                        f:view { place = 'overlapping',
                            f:popup_menu { value = bind 'geminiModel', items = Defaults.modelItems('gemini'), width = fieldWidth, visible = LrBinding.keyEquals('provider', 'gemini') },
                            f:popup_menu { value = bind 'openaiModel', items = Defaults.modelItems('openai'), width = fieldWidth, visible = LrBinding.keyEquals('provider', 'openai') },
                        },
                        f:push_button { title = '?', width = 24, action = function()
                            local provider = propertyTable.provider
                            LrDialogs.message('Model and cost', Defaults.pricingSummary(provider) .. '\n\nPer-photo estimates are rough and assume about 2,000 input and 1,000 output tokens per photo. Your provider dashboard is the authoritative source for cost; set a budget limit there.', 'info')
                        end },
                    },
                    f:row {
                        f:static_text { title = bind { key = 'provider', transform = function(value) return Defaults.providerInfo[value].keyName end }, alignment = 'right', width = share 'fsLabel' },
                        f:password_field { value = bind 'newApiKey', width = fieldWidth, immediate = true },
                        question('API key', 'Paste the key for the selected provider and choose Save. The field is always shown blank; a saved key stays saved until you paste a replacement.\n\nKeys are stored locally in Lightroom plug-in preferences.'),
                    },
                    indented(f:static_text { title = bind 'keyStatus', width = fieldWidth, height_in_lines = 2 }),
                    indented(f:row {
                        f:push_button { title = 'Save', action = function() saveSettings(propertyTable) end },
                        f:push_button { title = 'Check connection', action = checkConnection },
                        f:push_button { title = 'Get a key…', action = function() LrHttp.openUrlInBrowser(Defaults.providerInfo[propertyTable.provider].keyUrl) end },
                    }),
                    indented(f:static_text { title = bind 'connectionStatus', width = fieldWidth, height_in_lines = 2 }),
                },
            },
            f:group_box { title = 'Advanced (optional)', fill_horizontal = 1,
                f:column { spacing = f:control_spacing(),
                    f:row {
                        label('Creativity'),
                        f:slider { value = bind 'temperature', min = 0, max = 1, integral = false, width = 200 },
                        f:static_text { title = bind { key = 'temperature', transform = function(value) return string.format('%.2f', tonumber(value) or 0) end }, width = 40 },
                        question('Creativity', 'Lower values favour consistent factual wording. Higher values allow more variation but may require more correction. OpenAI GPT-5 models ignore this setting.'),
                    },
                    f:row {
                        label('Pause between photos (ms)'),
                        f:edit_field { value = bind 'batchDelayMs', min = 0, max = 10000, precision = 0, width = 70 },
                        question('Pause between photos', 'Increase this if your provider reports rate-limit errors. Busy or rate-limited requests are also retried automatically.'),
                    },
                },
            },
            f:static_text { title = bind 'readiness', width = 480 },
        },
    }}
end

function Provider.endDialog(propertyTable) saveSettings(propertyTable) end
return Provider
