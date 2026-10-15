local LrHttp = import 'LrHttp'
local LrTasks = import 'LrTasks'
local Json = require 'Json'
local Util = require 'Util'

local Client = {}

local requestTimeoutSeconds = 120
local retryDelaysSeconds = { 3, 8 }
local retryableStatus = { [429] = true, [500] = true, [502] = true, [503] = true, [504] = true }

local function providerError(response, headers)
    local status = headers and (headers.status or headers.error and headers.error.name) or 'no response'
    local detail = tostring(response or (headers and headers.error and headers.error.errorCode) or ''):gsub('%s+', ' '):sub(1, 300)
    error('Provider request failed (HTTP ' .. tostring(status) .. '): ' .. detail)
end

-- LrHttp expects headers as an array of { field =, value = } tables, not a map.
local function post(url, body, headerMap)
    local headers = {}
    for field, value in pairs(headerMap) do table.insert(headers, { field = field, value = value }) end
    local encoded = Json.encode(body)
    local response, responseHeaders
    for attempt = 1, #retryDelaysSeconds + 1 do
        response, responseHeaders = LrHttp.post(url, encoded, headers, 'POST', requestTimeoutSeconds)
        local status = responseHeaders and responseHeaders.status
        if status and status >= 200 and status < 300 then return Json.decode(response) end
        if not (status and retryableStatus[status]) or attempt > #retryDelaysSeconds then break end
        LrTasks.sleep(retryDelaysSeconds[attempt])
    end
    providerError(response, responseHeaders)
end

local function extractObject(text)
    text = Util.trim(text)
    local first, last = text:find('{'), text:match('.*()}')
    if not first or not last then error('The provider did not return a JSON object.') end
    return Json.decode(text:sub(first, last))
end

local function safeString(value)
    return Util.trim(type(value) == 'string' and value or '')
end

local function list(value)
    if type(value) == 'string' then return Util.split(value, ',') end
    return type(value) == 'table' and value or {}
end

function Client.normalise(result)
    if type(result) ~= 'table' then error('Invalid analysis response.') end
    local keywords = {}
    for _, keyword in ipairs(list(result.keywords)) do
        keyword = safeString(keyword)
        if keyword ~= '' then table.insert(keywords, keyword) end
    end
    keywords = Util.unique(keywords)
    while #keywords > 12 do table.remove(keywords) end
    -- Older prompts returned one combined "description"; use it for whichever field is missing.
    local legacy = safeString(result.description)
    local caption = Util.clip(safeString(result.caption) ~= '' and safeString(result.caption) or legacy, 500)
    local altText = Util.clip(safeString(result.alt_text) ~= '' and safeString(result.alt_text) or legacy, 250)
    local title = Util.clip(safeString(result.title), 120):gsub('%.$', '')
    if title == '' and caption == '' and altText == '' and #keywords == 0 then error('The provider returned no usable metadata.') end
    local portfolio = type(result.portfolio) == 'table' and result.portfolio or {}
    local score = math.floor(math.max(1, math.min(5, tonumber(portfolio.score) or 3)) + 0.5)
    local labels = { [1] = 'Reject candidate', [2] = 'Needs review', [3] = 'Supporting', [4] = 'Portfolio', [5] = 'Hero' }
    return {
        title = title,
        keywords = keywords,
        caption = caption,
        altText = altText,
        confidence = math.max(0, math.min(1, tonumber(result.confidence) or 0.5)),
        portfolio = {
            score = score,
            label = labels[score],
            recommendedUse = safeString(portfolio.recommended_use),
            strengths = Util.unique(list(portfolio.strengths)),
            cautions = Util.unique(list(portfolio.cautions)),
        },
    }
end

-- Free check (no image, no tokens): asks the provider for the selected model's details,
-- which proves the key is accepted and that this key can use that model.
-- Returns ok, message.
function Client.checkConnection(provider, key, model)
    key = Util.trim(key)
    local info = provider == 'openai' and 'OpenAI' or 'Gemini'
    if key == '' then return false, 'No ' .. info .. ' API key saved yet.' end
    local url, headers
    if provider == 'openai' then
        url, headers = 'https://api.openai.com/v1/models/' .. model, { { field = 'Authorization', value = 'Bearer ' .. key } }
    else
        url, headers = 'https://generativelanguage.googleapis.com/v1beta/models/' .. model .. '?key=' .. key, {}
    end
    local _, responseHeaders = LrHttp.get(url, headers, 30)
    local status = responseHeaders and responseHeaders.status
    if status and status >= 200 and status < 300 then return true, '✓ Connected. ' .. model .. ' is available with this key.' end
    if status == 400 or status == 401 or status == 403 then return false, '✗ ' .. info .. ' rejected the key (HTTP ' .. status .. '). Paste it again and save.' end
    if status == 404 then return false, '✗ The key works, but ' .. model .. ' is not available to it. Choose another model.' end
    if status == 429 then return false, '✗ The key works but is rate-limited or out of credit (HTTP 429). Check billing.' end
    if status then return false, '✗ ' .. info .. ' returned HTTP ' .. status .. '. Try again shortly.' end
    return false, '✗ Could not reach ' .. info .. '. Check the internet connection.'
end

-- GPT-5 and o-series reasoning models reject any temperature other than the default.
function Client.acceptsTemperature(model)
    model = string.lower(model or '')
    return not (model:match('^gpt%-5') or model:match('^o%d'))
end

function Client.analyse(settings, imageBase64, context)
    if settings.provider == 'gemini' then
        local key = Util.trim(settings.geminiApiKey)
        if key == '' then error('Gemini API key is missing. Add it in File → Plug-in Manager → FrameSense AI.') end
        local body = {
            system_instruction = { parts = { { text = settings.prompt } } },
            contents = { { role = 'user', parts = { { text = context }, { inline_data = { mime_type = 'image/jpeg', data = imageBase64 } } } } },
            generationConfig = { temperature = settings.temperature, responseMimeType = 'application/json' },
        }
        local url = 'https://generativelanguage.googleapis.com/v1beta/models/' .. settings.geminiModel .. ':generateContent?key=' .. key
        local decoded = post(url, body, { ['Content-Type'] = 'application/json' })
        local candidate = decoded.candidates and decoded.candidates[1]
        local texts = {}
        for _, part in ipairs(candidate and candidate.content and candidate.content.parts or {}) do
            if type(part.text) == 'string' and not part.thought then table.insert(texts, part.text) end
        end
        if #texts == 0 then
            local reason = candidate and candidate.finishReason or (decoded.promptFeedback and decoded.promptFeedback.blockReason)
            error('Gemini returned no analysis text' .. (reason and (' (' .. tostring(reason) .. ')') or '') .. '.')
        end
        return Client.normalise(extractObject(table.concat(texts))), decoded.usageMetadata
    end

    local key = Util.trim(settings.openaiApiKey)
    if key == '' then error('OpenAI API key is missing. Add it in File → Plug-in Manager → FrameSense AI.') end
    local body = {
        model = settings.openaiModel,
        response_format = { type = 'json_object' },
        messages = {
            { role = 'system', content = settings.prompt },
            { role = 'user', content = { { type = 'text', text = context }, { type = 'image_url', image_url = { url = 'data:image/jpeg;base64,' .. imageBase64 } } } },
        },
    }
    if Client.acceptsTemperature(settings.openaiModel) then body.temperature = settings.temperature end
    local decoded = post('https://api.openai.com/v1/chat/completions', body, { ['Content-Type'] = 'application/json', ['Authorization'] = 'Bearer ' .. key })
    local choice = decoded.choices and decoded.choices[1]
    local text = choice and choice.message and choice.message.content
    if type(text) ~= 'string' or text == '' then
        error('OpenAI returned no analysis text' .. (choice and choice.finish_reason and (' (' .. tostring(choice.finish_reason) .. ')') or '') .. '.')
    end
    return Client.normalise(extractObject(text)), decoded.usage
end

return Client
