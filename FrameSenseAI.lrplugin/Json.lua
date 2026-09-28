-- Small self-contained JSON reader/writer for provider responses and requests.
local Json = {}

local function utf8char(code)
    if code < 128 then return string.char(code) end
    if code < 2048 then return string.char(192 + math.floor(code / 64), 128 + (code % 64)) end
    return string.char(224 + math.floor(code / 4096), 128 + (math.floor(code / 64) % 64), 128 + (code % 64))
end

local function escape(value)
    value = tostring(value or '')
    value = value:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\b', '\\b'):gsub('\f', '\\f'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t')
    return '"' .. value .. '"'
end

function Json.encode(value)
    local kind = type(value)
    if kind == 'nil' then return 'null' end
    if kind == 'boolean' then return value and 'true' or 'false' end
    if kind == 'number' then return tostring(value) end
    if kind == 'string' then return escape(value) end
    if kind ~= 'table' then error('JSON cannot encode ' .. kind) end
    local isArray, max = true, 0
    for key, _ in pairs(value) do
        if type(key) ~= 'number' then isArray = false break end
        if key > max then max = key end
    end
    local output = {}
    if isArray then
        for i = 1, max do table.insert(output, Json.encode(value[i])) end
        return '[' .. table.concat(output, ',') .. ']'
    end
    for key, item in pairs(value) do table.insert(output, escape(key) .. ':' .. Json.encode(item)) end
    return '{' .. table.concat(output, ',') .. '}'
end

function Json.decode(text)
    local index, length = 1, #(text or '')
    local function whitespace()
        while index <= length and text:sub(index, index):match('%s') do index = index + 1 end
    end
    local parseValue
    local function parseString()
        index = index + 1
        local output = {}
        while index <= length do
            local char = text:sub(index, index)
            if char == '"' then index = index + 1; return table.concat(output) end
            if char ~= '\\' then table.insert(output, char); index = index + 1
            else
                local escaped = text:sub(index + 1, index + 1)
                local map = { ['"'] = '"', ['\\'] = '\\', ['/'] = '/', b = '\b', f = '\f', n = '\n', r = '\r', t = '\t' }
                if escaped == 'u' then
                    local code = tonumber(text:sub(index + 2, index + 5), 16)
                    if not code then error('Invalid JSON unicode escape') end
                    table.insert(output, utf8char(code)); index = index + 6
                elseif map[escaped] then table.insert(output, map[escaped]); index = index + 2
                else error('Invalid JSON escape') end
            end
        end
        error('Unclosed JSON string')
    end
    local function parseArray()
        index = index + 1; whitespace()
        local result = {}
        if text:sub(index, index) == ']' then index = index + 1; return result end
        while true do
            table.insert(result, parseValue()); whitespace()
            local char = text:sub(index, index)
            if char == ']' then index = index + 1; return result end
            if char ~= ',' then error('Expected JSON array comma') end
            index = index + 1; whitespace()
        end
    end
    local function parseObject()
        index = index + 1; whitespace()
        local result = {}
        if text:sub(index, index) == '}' then index = index + 1; return result end
        while true do
            if text:sub(index, index) ~= '"' then error('Expected JSON key') end
            local key = parseString(); whitespace()
            if text:sub(index, index) ~= ':' then error('Expected JSON colon') end
            index = index + 1; whitespace(); result[key] = parseValue(); whitespace()
            local char = text:sub(index, index)
            if char == '}' then index = index + 1; return result end
            if char ~= ',' then error('Expected JSON object comma') end
            index = index + 1; whitespace()
        end
    end
    function parseValue()
        whitespace(); local char = text:sub(index, index)
        if char == '"' then return parseString() end
        if char == '{' then return parseObject() end
        if char == '[' then return parseArray() end
        if text:sub(index, index + 3) == 'true' then index = index + 4; return true end
        if text:sub(index, index + 4) == 'false' then index = index + 5; return false end
        if text:sub(index, index + 3) == 'null' then index = index + 4; return nil end
        local number = text:match('^-?%d+%.?%d*[eE]?[-+]?%d*', index)
        if number and #number > 0 then index = index + #number; return tonumber(number) end
        error('Invalid JSON value at character ' .. index)
    end
    local result = parseValue(); whitespace()
    if index <= length then error('Unexpected JSON data after character ' .. index) end
    return result
end

return Json
