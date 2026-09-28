-- Contract simulation only: no Lightroom, photo I/O, catalogue writes or API calls.
-- Resolve the plug-in folder relative to this file so tests run from any directory.
local testDir = (arg and arg[0] or ''):match('^(.*)[/\\]') or '.'
local pluginDir = testDir .. '/../FrameSenseAI.lrplugin/'
package.path = pluginDir .. '?.lua;' .. package.path
local active, tables, dialogs, calls = nil, 0, 0, 0
local prefs = {}
local photos = {}
local writes, learned, applied = {}, false, {}
local confirms, reviewCancels = {}, 0
local paths = { '/test/Restaurant/frame1.jpg', '/test/Restaurant/frame2.jpg', '/test/Restaurant/frame3.jpg', '/test/Restaurant/frame4.CR3' }
for i = 1, #paths do
    photos[i] = {
        getRawMetadata = function() return paths[i] end,
        setRawMetadata = function(_, key, value) writes[#writes + 1] = { i, key, value } end,
        setPropertyForPlugin = function() end,
        addKeyword = function(_, keyword) applied[i] = applied[i] or {}; table.insert(applied[i], keyword) end,
    }
end
-- Mirrors LrCatalog:createKeyword: an existing keyword is returned only with returnExisting.
local existingKeywords = { ['restaurant interior'] = true }
local created = 0
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
 createKeyword = function(_, term, _, _, _, returnExisting)
    if existingKeywords[term] and not returnExisting then return false end
    if not existingKeywords[term] then created = created + 1; existingKeywords[term] = true end
    return term
 end,
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
    tables = tables + 1
    local observers = {}
    return setmetatable({}, { __index = { addObserver = function(self, key, fn) observers[key] = fn end } })
 end, keyEquals = function(key, value) return { key = key, equals = value } end },
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
    assert(p.selectedSummary:find('3 of 3', 1, true), 'missing live selection summary')
    if reviewCancels == 0 then reviewCancels = 1; return 'cancel' end -- first Cancel is withdrawn at the confirmation
    p.title2 = '   ' -- a cleared title must not wipe the existing catalogue title
    assert(findKind(spec.contents, 'group_box') >= 3, 'missing review rows')
    assert(findKind(spec.contents, 'catalog_photo') == 3, 'missing catalogue previews')
    p.applyRatings = true
    p.score1 = '5'; p.score2 = '4'; p.score3 = '3'
    return 'ok'
 end, message = function() error('Unexpected error dialog') end,
 confirm = function(message) table.insert(confirms, message); return message:find('Discard', 1, true) and 'cancel' or 'ok' end },
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
 LrSystemInfo = { displayInfo = function() return { { width = 1440, height = 900 } } end },
 LrTasks = { startAsyncTask = function(fn) fn() end, pcall = function(fn) calls = calls + 1; return pcall(fn) end, sleep = function() end },
 LrView = { osFactory = function() return factory end, bind = function(k) return k end },
}
function import(name) return assert(namespaces[name], 'Unsupported namespace ' .. name) end
package.loaded.LearningStore = { get = function() return {} end, remember = function() learned = true end }
package.loaded.ProviderClient = { analyse = function() return { title = 'Test title', keywords = {'restaurant interior', 'banquette seating'}, description = 'Test description', confidence = .9, portfolio = {score = 3, strengths = {'Strong composition'}, cautions = {'Crop is tight'}} } end }
prefs.sharedTags = 'Banquette Seating, Test Resort'
_PLUGIN = {}
local realOpen = io.open
io.open = function(path)
    assert(path == 'mock-derivative')
    return { read = function() return 'mock' end, close = function() end }
end
dofile(pluginDir .. 'AnalyzeSelected.lua')
io.open = realOpen
assert(tables == 2 and dialogs == 3 and calls == 3, 'expected preflight, cancelled review, review and three analyses')
assert(#confirms == 2 and confirms[1]:find('1 of 4', 1, true), 'RAW file should be skipped with consent, not block the batch')
for i = 1, 3 do
    local names = table.concat(applied[i] or {}, '|')
    assert(names:find('restaurant interior', 1, true), 'pre-existing catalogue keyword was not applied to photo ' .. i)
    assert(names:find('Test Resort', 1, true), 'shared keyword missing on photo ' .. i)
    assert(#applied[i] == 3, 'case-insensitive duplicate shared keyword was applied twice')
end
assert(created == 2, 'keywords should be created once per batch, not per photo')
for _, write in ipairs(writes) do assert(not (write[1] == 2 and write[2] == 'title'), 'blank title overwrote the catalogue title') end
assert(not applied[4], 'RAW file should not have been processed')
assert(prefs.analysisPrompt:find('Test remembered instruction', 1, true))
assert(learned and #writes > 0)
local sawFive, sawBlue = false, false
for _, write in ipairs(writes) do
    if write[2] == 'rating' and write[3] == 5 then sawFive = true end
    if write[2] == 'colorNameForLabel' and write[3] == 'blue' then sawBlue = true end
end
assert(sawFive and sawBlue, 'rating or active colour-label mapping was not written')
print('PASS: contexts, RAW skipped with consent, prompt persistence, catalog previews, cancel confirmation, three rows, existing keywords reused, blank title preserved, rating opt-in, native colour assignment')
