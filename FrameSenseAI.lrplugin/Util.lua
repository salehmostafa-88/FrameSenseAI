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
    local labels = {
        Util.usefulFolderLabel(Util.leaf(folder)),
        Util.usefulFolderLabel(Util.leaf(Util.parent(folder))),
    }
    return Util.unique(labels)
end

function Util.localFileExists(path)
    local ok, attributes = pcall(LrFileUtils.fileAttributes, path)
    return ok and attributes ~= nil
end

function Util.clip(value, maxLength)
    value = Util.trim(value)
    if #value > maxLength then return value:sub(1, maxLength - 1) .. '…' end
    return value
end

function Util.csvEscape(value)
    value = tostring(value or ''):gsub('"', '""')
    return '"' .. value .. '"'
end

return Util
