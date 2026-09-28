-- Contract simulation only: no Lightroom, photo I/O, catalogue writes or API calls.
package.path = 'framesense-ai-lightroom/FrameSenseAI.lrplugin/?.lua;' .. package.path
local active, tables, dialogs, calls = nil, 0, 0, 0
local prefs = {}
local photos = {}
local writes, learned = {}, false
for i = 1, 3 do
    photos[i] = {
        getRawMetadata = function() return '/test/Restaurant/frame' .. i .. '.jpg' end,
        setRawMetadata = function(_, key, value) writes[#writes + 1] = { i, key, value } end,
        setPropertyForPlugin = function() end,
        addKeyword = function() end,
    }
end
local factory = setmetatable({}, { __index = function(_, kind)
    return function(_, spec, extra)
        if kind == 'control_spacing' then return 6 end
        assert(type(spec) == 'table' and extra == nil, 'View requires one table')
        spec.kind = kind
        return spec
    end
end })
local catalog = {
 getTargetPhotos = function() return photos end,
 withWriteAccessDo = function(_, _, fn) fn() end,
 createKeyword = function(_, term) return term end,
}
local function findKind(node, kind)
    if type(node) ~= 'table' then return 0 end
    local count = node.kind == kind and 1 or 0
    for _, child in pairs(node) do count = count + findKind(child, kind) end
    return count
end
local namespaces = {
 LrApplication = { activeCatalog = function() return catalog end },
 LrBinding = { makePropertyTable = function(context)
    assert(context and context == active, 'missing functionContext')
    tables = tables + 1; return {}
 end },
 LrDialogs = { presentModalDialog = function(spec)
    dialogs = dialogs + 1
    local p = assert(spec.contents.bind_to_object, 'missing binding')
    if dialogs == 1 then
        assert(p.provider == 'gemini')
        assert(p.analysisPrompt and p.analysisPrompt:find('frame%-specific'))
        assert(p.folderPreview:find('Restaurant', 1, true))
        p.analysisPrompt = p.analysisPrompt .. '\nTest remembered instruction.'
        return 'ok'
    end
    assert(p.title1 == 'Test title' and p.title3 == 'Test title')
    assert(findKind(spec.contents, 'group_box') >= 3, 'missing review rows')
    assert(findKind(spec.contents, 'catalog_photo') == 3, 'missing catalogue previews')
    p.applyRatings = true
    p.score1 = '5'; p.score2 = '4'; p.score3 = '3'
    return 'ok'
 end, message = function() error('Unexpected error dialog') end },
 LrExportSession = function(spec)
    assert(spec.photosToExport[1].getRawMetadata, 'expected photo object')
    return { renditions = function()
        local done = false
        return function()
            if done then return end; done = true
            return 1, { waitForRender = function() return true, 'mock-derivative' end }
        end
    end }
 end,
 LrFileUtils = { fileAttributes = function() return {} end, createAllDirectories = function() end, delete = function() end },
 LrFunctionContext = { callWithContext = function(_, fn) active = {}; fn(active); active = nil end },
 LrPathUtils = { child = function(a,b) return a .. '/' .. b end, getStandardFilePath = function() return '/mock' end },
 LrPrefs = { prefsForPlugin = function() return prefs end },
 LrProgressScope = function() return { isCanceled = function() return false end, setPortionComplete = function() end, setCaption = function() end, done = function() end } end,
 LrStringUtils = { encodeBase64 = function() return 'mock' end },
 LrTasks = { startAsyncTask = function(fn) fn() end, pcall = function(fn) calls = calls + 1; return pcall(fn) end, sleep = function() end },
 LrView = { osFactory = function() return factory end, bind = function(k) return k end },
}
function import(name) return assert(namespaces[name], 'Unsupported namespace ' .. name) end
package.loaded.LearningStore = { get = function() return {} end, remember = function() learned = true end }
package.loaded.ProviderClient = { analyse = function() return { title = 'Test title', keywords = {'restaurant interior'}, description = 'Test description', confidence = .9, portfolio = {score = 3, strengths = {'Strong composition'}} } end }
_PLUGIN = {}
local realOpen = io.open
io.open = function(path)
    assert(path == 'mock-derivative')
    return { read = function() return 'mock' end, close = function() end }
end
dofile('framesense-ai-lightroom/FrameSenseAI.lrplugin/AnalyzeSelected.lua')
io.open = realOpen
assert(tables == 2 and dialogs == 2 and calls == 3)
assert(prefs.analysisPrompt:find('Test remembered instruction', 1, true))
assert(learned and #writes > 0)
local sawFive, sawBlue = false, false
for _, write in ipairs(writes) do
    if write[2] == 'rating' and write[3] == 5 then sawFive = true end
    if write[2] == 'colorNameForLabel' and write[3] == 'blue' then sawBlue = true end
end
assert(sawFive and sawBlue, 'rating or active colour-label mapping was not written')
print('PASS: contexts, prompt persistence, catalog previews, three rows, rating opt-in, native colour assignment, catalogue writes')
