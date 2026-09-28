local LrFileUtils = import 'LrFileUtils'

local Util = {}

function Util.trim(value)
    return (tostring(value or ''):gsub('^%s*(.-)%s*$', '%1'))
end

function Util.split(value, delimiter)
    local result = {}
    for item in string.gmatch(value or '', '([^' .. delimiter .. ']+)') do
        item = Util.trim(item)
        if item ~= '' then table.insert(result, item) end
    end
    return result
end

function Util.unique(items)
    local result, seen = {}, {}
    if type(items) == 'string' then items = { items } end
    for _, item in ipairs(items or {}) do
        item = Util.trim(item)
        local key = string.lower(item)
        if item ~= '' and not seen[key] then
            seen[key] = true
            table.insert(result, item)
        end
    end
    return result
end

function Util.isJpeg(path)
    return string.lower(path or ''):match('%.jpe?g$') ~= nil
end

function Util.parent(path)
    return (path or ''):match('^(.*)[/\\][^/\\]+$') or ''
end

function Util.leaf(path)
    path = (path or ''):gsub('[/\\]+$', '')
    return path:match('([^/\\]+)$') or ''
end

local rejectedFolders = {
    jpg = true, jpeg = true, photo = true, photos = true, image = true, images = true,
    delivery = true, deliveries = true, export = true, exports = true, final = true,
    finals = true, select = true, selects = true,
}

function Util.usefulFolderLabel(label)
    label = Util.trim(label)
    local lower = string.lower(label)
    if label == '' or rejectedFolders[lower] or lower:match('^%d%d%d%d$') then return nil end
    return label
end

function Util.folderHints(path)
    local folder = Util.parent(path)
    -- Skip rejected labels explicitly: a nil first entry would hide the parent label from ipairs.
    local labels = {}
    for _, candidate in ipairs { Util.leaf(folder), Util.leaf(Util.parent(folder)) } do
        local label = Util.usefulFolderLabel(candidate)
        if label then table.insert(labels, label) end
    end
    return Util.unique(labels)
end

function Util.localFileExists(path)
    local ok, attributes = pcall(LrFileUtils.fileAttributes, path)
    return ok and attributes ~= nil
end

-- Number of UTF-8 characters (not bytes); Format and alt-text limits count characters.
function Util.length(value)
    local _, count = tostring(value or ''):gsub('[^\128-\191]', '')
    return count
end

-- Clips to at most maxLength UTF-8 characters, including the trailing ellipsis,
-- preferring a word boundary and never splitting a multi-byte character.
function Util.clip(value, maxLength)
    value = Util.trim(value)
    if Util.length(value) <= maxLength then return value end
    local keep, count, cut = maxLength - 1, 0, #value
    for position in value:gmatch('()[^\128-\191]') do
        if count == keep then cut = position - 1 break end
        count = count + 1
    end
    local clipped = value:sub(1, cut)
    local atWord = clipped:match('^(.*%S)%s+%S*$')
    if atWord and Util.length(atWord) >= keep * 0.8 then clipped = atWord end
    return Util.trim(clipped):gsub('[%s,;:%.%-]+$', '') .. '…'
end

return Util
