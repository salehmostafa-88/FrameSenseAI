local LrHttp = import 'LrHttp'
local Json = require 'Json'
local Util = require 'Util'

local Client = {}

local function providerError(response, headers)
    local status = headers and headers.status or 'unknown'
    local detail = tostring(response or ''):gsub('%s+', ' '):sub(1, 300)
    error('Provider request failed (HTTP ' .. tostring(status) .. '): ' .. detail)
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

function Client.normalise(result)
    if type(result) ~= 'table' then error('Invalid analysis response.') end
    local keywords = {}
    for _, keyword in ipairs(result.keywords or {}) do
        keyword = safeString(keyword)
        if keyword ~= '' then table.insert(keywords, keyword) end
    end
    keywords = Util.unique(keywords)
    if #keywords < 1 then error('The provider returned no usable keywords.') end
    while #keywords > 12 do table.remove(keywords) end
    local description = Util.clip(safeString(result.description), 255)
    if description == '' then error('The provider returned no usable description.') end
    local portfolio = result.portfolio or {}
    local score = math.max(1, math.min(5, tonumber(portfolio.score) or 3))
    local labels = { [1] = 'Reject candidate', [2] = 'Needs review', [3] = 'Supporting', [4] = 'Portfolio', [5] = 'Hero' }
    return {
        title = safeString(result.title),
        keywords = keywords,
        description = description,
        altText = description,
        confidence = math.max(0, math.min(1, tonumber(result.confidence) or 0.5)),
        portfolio = {
            score = score,
            label = labels[score],
            recommendedUse = safeString(portfolio.recommended_use),
            strengths = Util.unique(portfolio.strengths or {}),
            cautions = Util.unique(portfolio.cautions or {}),
        },
    }
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
        local response, headers = LrHttp.post(url, Json.encode(body), { ['Content-Type'] = 'application/json' })
        if not headers or headers.status < 200 or headers.status >= 300 then providerError(response, headers) end
        local decoded = Json.decode(response)
        local parts = decoded.candidates and decoded.candidates[1] and decoded.candidates[1].content and decoded.candidates[1].content.parts
        local text = parts and parts[1] and parts[1].text
        if not text then error('Gemini returned no analysis text.') end
        return Client.normalise(extractObject(text)), decoded.usageMetadata
    end

    local key = Util.trim(settings.openaiApiKey)
    if key == '' then error('OpenAI API key is missing. Add it in File → Plug-in Manager → FrameSense AI.') end
    local body = {
        model = settings.openaiModel,
        temperature = settings.temperature,
        response_format = { type = 'json_object' },
        messages = {
            { role = 'system', content = settings.prompt },
            { role = 'user', content = { { type = 'text', text = context }, { type = 'image_url', image_url = { url = 'data:image/jpeg;base64,' .. imageBase64 } } } },
        },
    }
    local response, headers = LrHttp.post('https://api.openai.com/v1/chat/completions', Json.encode(body), { ['Content-Type'] = 'application/json', ['Authorization'] = 'Bearer ' .. key })
    if not headers or headers.status < 200 or headers.status >= 300 then providerError(response, headers) end
    local decoded = Json.decode(response)
    local text = decoded.choices and decoded.choices[1] and decoded.choices[1].message and decoded.choices[1].message.content
    if not text then error('OpenAI returned no analysis text.') end
    return Client.normalise(extractObject(text)), decoded.usage
end

return Client
