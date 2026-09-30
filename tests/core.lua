-- Unit tests for the non-UI modules: Json, Util, ProviderClient (mocked LrHttp) and LearningStore.
-- No network calls are made; this checks the request contract, not the provider services.
local testDir = (arg and arg[0] or ''):match('^(.*)[/\\]') or '.'
package.path = testDir .. '/../FrameSenseAI.lrplugin/?.lua;' .. package.path

local prefs, posts, responses, sleeps = {}, {}, {}, {}
local namespaces = {
    LrFileUtils = { fileAttributes = function() return {} end },
    LrPrefs = { prefsForPlugin = function() return prefs end },
    LrTasks = { sleep = function(seconds) table.insert(sleeps, seconds) end },
    LrHttp = { post = function(url, body, headers, method, timeout)
        table.insert(posts, { url = url, body = body, headers = headers, method = method, timeout = timeout })
        local nextResponse = table.remove(responses, 1)
        return nextResponse[1], nextResponse[2]
    end, get = function(url, headers)
        table.insert(posts, { url = url, headers = headers })
        local nextResponse = table.remove(responses, 1)
        return nextResponse[1], nextResponse[2]
    end },
}
function import(name) return assert(namespaces[name], 'Unsupported namespace ' .. name) end

local Json = require 'Json'
local Util = require 'Util'
local ProviderClient = require 'ProviderClient'
local LearningStore = require 'LearningStore'

local function expectError(fn, fragment)
    local ok, message = pcall(fn)
    assert(not ok, 'expected an error containing: ' .. fragment)
    assert(tostring(message):find(fragment, 1, true), 'unexpected error: ' .. tostring(message))
end

-- Json ---------------------------------------------------------------------------------------
local decoded = Json.decode('{"a":[1,2.5,-3e2,true,false,null],"s":"line\\nquote\\" caf\\u00e9 \\ud83d\\udcf7"}')
assert(decoded.a[2] == 2.5 and decoded.a[3] == -300 and decoded.a[4] == true and decoded.a[5] == false)
assert(decoded.s == 'line\nquote" café 📷', 'escapes or surrogate pair decoded incorrectly')
local roundTrip = Json.decode(Json.encode({ text = 'tab\there\1bell', list = { 'x', 'y' }, n = 0.2 }))
assert(roundTrip.text == 'tab\there\1bell' and roundTrip.list[2] == 'y' and roundTrip.n == 0.2)
assert(not Json.encode('a\1b'):find('\1', 1, true), 'raw control character left in JSON output')
expectError(function() Json.decode('{"a":1} trailing') end, 'Unexpected JSON data')
expectError(function() Json.decode('{"a":') end, 'Invalid JSON value')

-- Util ---------------------------------------------------------------------------------------
assert(table.concat(Util.split(' a, b ,,c ', ','), '|') == 'a|b|c')
assert(table.concat(Util.unique({ 'Pool', 'pool', ' Bar ' }), '|') == 'Pool|Bar')
assert(Util.isJpeg('/x/Y.JPEG') and Util.isJpeg('a.jpg') and not Util.isJpeg('a.cr3'))
assert(table.concat(Util.folderHints('/Users/me/Clients/AlFresco Restaurant/Finals/img.jpg'), '|') == 'AlFresco Restaurant')
assert(table.concat(Util.folderHints('C:\\Shoots\\2026\\Lobby\\img.jpg'), '|') == 'Lobby')
assert(Util.length('Mövenpick café') == 14)
local long = string.rep('Sunlit terrace with rattan chairs ', 12) .. 'ending ü'
local clipped = Util.clip(long, 255)
assert(Util.length(clipped) <= 255, 'clip exceeded 255 characters: ' .. Util.length(clipped))
assert(clipped:sub(-3) == '…' and not clipped:find('%s…$'), 'clip should end cleanly with an ellipsis')
local accented = Util.clip(string.rep('é', 300), 255)
assert(Util.length(accented) == 255 and not accented:find('[\195][^\128-\191]'), 'clip split a UTF-8 character')
assert(Util.clip('  short  ', 255) == 'short')

-- ProviderClient.normalise -------------------------------------------------------------------
local normal = ProviderClient.normalise({
    title = ' Pool deck ', keywords = 'pool area, sun loungers, Pool Area', description = 'A pool.', confidence = 3,
    portfolio = { score = 4.6, strengths = 'Clear light', cautions = { 'Busy edge' } },
})
assert(normal.title == 'Pool deck' and #normal.keywords == 2, 'comma-string keywords should be split and de-duplicated')
assert(normal.confidence == 1 and normal.portfolio.score == 5 and normal.portfolio.label == 'Hero')
assert(normal.portfolio.strengths[1] == 'Clear light' and normal.portfolio.cautions[1] == 'Busy edge')
local many = {}
for i = 1, 20 do many[i] = 'term ' .. i end
assert(#ProviderClient.normalise({ keywords = many, description = 'x' }).keywords == 12)
expectError(function() ProviderClient.normalise({ keywords = {}, description = 'x' }) end, 'no usable keywords')
expectError(function() ProviderClient.normalise({ keywords = { 'a' }, description = ' ' }) end, 'no usable description')

-- ProviderClient.analyse: request contract --------------------------------------------------
local analysis = '{"title":"Bar","keywords":["bar interior"],"description":"A bar.","confidence":0.9,"portfolio":{"score":3}}'
local function headerValue(headers, field)
    for _, header in ipairs(headers) do
        assert(type(header) == 'table' and header.field and header.value, 'LrHttp headers must be { field =, value = } entries')
        if header.field == field then return header.value end
    end
end
local settings = {
    provider = 'openai', openaiModel = 'gpt-4o-mini', openaiApiKey = ' sk-test ', geminiModel = 'gemini-3.5-flash',
    geminiApiKey = 'g-test', temperature = 0.2, prompt = 'Return JSON only.',
}

responses = { { Json.encode({ choices = { { message = { content = analysis } } } }), { status = 200 } } }
local result = ProviderClient.analyse(settings, 'BASE64', 'context')
assert(result.title == 'Bar')
local request = posts[#posts]
assert(headerValue(request.headers, 'Authorization') == 'Bearer sk-test', 'OpenAI Authorization header not sent in LrHttp format')
assert(request.method == 'POST' and request.timeout and request.timeout >= 60, 'explicit POST method and long timeout expected')
local body = Json.decode(request.body)
assert(body.temperature == 0.2 and body.messages[2].content[2].image_url.url == 'data:image/jpeg;base64,BASE64')

settings.openaiModel = 'gpt-5-mini'
responses = { { Json.encode({ choices = { { message = { content = analysis } } } }), { status = 200 } } }
ProviderClient.analyse(settings, 'BASE64', 'context')
assert(Json.decode(posts[#posts].body).temperature == nil, 'GPT-5 models reject a custom temperature')

settings.provider = 'gemini'
responses = {
    { 'busy', { status = 503 } },
    { Json.encode({ candidates = { { content = { parts = { { text = 'thinking…', thought = true }, { text = analysis } } } } } }), { status = 200 } },
}
result = ProviderClient.analyse(settings, 'BASE64', 'context')
assert(result.keywords[1] == 'bar interior', 'Gemini thought parts must be ignored')
assert(#sleeps == 1, 'a 503 should be retried once before succeeding')
assert(headerValue(posts[#posts].headers, 'Content-Type') == 'application/json')
assert(posts[#posts].url:find('/models/gemini-3.5-flash:generateContent', 1, true))

sleeps = {}
responses = { { 'rate limited', { status = 429 } }, { 'rate limited', { status = 429 } }, { 'rate limited', { status = 429 } } }
expectError(function() ProviderClient.analyse(settings, 'BASE64', 'context') end, 'HTTP 429')
assert(#sleeps == 2, 'retries should stop after two waits')

sleeps = {}
responses = { { '{"error":"bad key"}', { status = 400 } } }
expectError(function() ProviderClient.analyse(settings, 'BASE64', 'context') end, 'HTTP 400')
assert(#sleeps == 0, 'client errors must not be retried')

responses = { { nil, { error = { errorCode = 'cannotConnectToHost', name = 'NetworkError' } } } }
expectError(function() ProviderClient.analyse(settings, 'BASE64', 'context') end, 'NetworkError')

responses = { { Json.encode({ candidates = { { finishReason = 'SAFETY' } } }), { status = 200 } } }
expectError(function() ProviderClient.analyse(settings, 'BASE64', 'context') end, 'SAFETY')

settings.geminiApiKey = '  '
expectError(function() ProviderClient.analyse(settings, 'BASE64', 'context') end, 'Gemini API key is missing')

-- ProviderClient.checkConnection -----------------------------------------------------------
local ok, message = ProviderClient.checkConnection('gemini', ' ', 'gemini-3.5-flash')
assert(not ok and message:find('No Gemini API key', 1, true))
responses = { { '{}', { status = 200 } } }
ok, message = ProviderClient.checkConnection('gemini', 'g-key', 'gemini-3.5-flash')
assert(ok and message:find('gemini-3.5-flash is available', 1, true) and posts[#posts].url:find('/models/gemini-3.5-flash?key=g-key', 1, true))
responses = { { '{}', { status = 401 } } }
ok, message = ProviderClient.checkConnection('openai', 'sk', 'gpt-5.4-mini')
assert(not ok and message:find('rejected the key', 1, true) and headerValue(posts[#posts].headers, 'Authorization') == 'Bearer sk')
responses = { { '{}', { status = 429 } } }
assert(select(2, ProviderClient.checkConnection('openai', 'sk', 'gpt-5.4-mini')):find('credit', 1, true))
responses = { { nil, { error = { name = 'NetworkError' } } } }
assert(select(2, ProviderClient.checkConnection('openai', 'sk', 'gpt-5.4-mini')):find('Could not reach OpenAI', 1, true))

-- LearningStore ------------------------------------------------------------------------------
LearningStore.remember('Mövenpick Taba', { { enabled = true, keywords = { 'pool area', 'Pool Area', 'sun loungers' } }, { enabled = false, keywords = { 'rejected term' } } })
local vocabulary = LearningStore.get(' Mövenpick Taba ')
assert(#vocabulary == 2 and vocabulary[1] == 'pool area', 'only approved rows should be remembered, once each')
assert(#LearningStore.get('') == 0 and #LearningStore.get('Another project') == 0)
local bulk = {}
for i = 1, 100 do bulk[i] = 'term ' .. i end
LearningStore.remember('Mövenpick Taba', { { enabled = true, keywords = bulk } })
vocabulary = LearningStore.get('Mövenpick Taba')
assert(#vocabulary == 80 and vocabulary[80] == 'term 100', 'vocabulary should keep the 80 most recent terms')

print('PASS: connection check messages, JSON escapes and emoji, UTF-8 clipping, folder hints, response normalising, LrHttp header format, retry/backoff, GPT-5 temperature, Gemini thought parts, network errors, learning profiles')
