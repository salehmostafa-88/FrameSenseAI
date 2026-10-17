-- Contract simulation only: no Lightroom, photo I/O, catalogue writes or API calls.
-- Resolve the plug-in folder relative to this file so tests run from any directory.
local testDir = (arg and arg[0] or ''):match('^(.*)[/\\]') or '.'
local pluginDir = testDir .. '/../FrameSenseAI.lrplugin/'
package.path = pluginDir .. '?.lua;' .. package.path
local active, tables, dialogs = nil, 0, 0
-- Lightroom's Lua 5.1 cannot yield across a plain pcall. Catalog reads may yield, so the
-- mock fails them whenever a plain pcall is on the stack, exactly as Lightroom does.
local realPcall, plainPcallDepth = pcall, 0
local function pack(...) return { n = select('#', ...), ... } end
pcall = function(fn, ...)
    plainPcallDepth = plainPcallDepth + 1
    local results = pack(realPcall(fn, ...))
    plainPcallDepth = plainPcallDepth - 1
    return unpack(results, 1, results.n)
end
local function catalogRead()
    if plainPcallDepth > 0 then error('attempt to yield across metamethod/C-call boundary') end
end
local prefs = { geminiApiKey = 'fake-test-key' }
local messages = {}
local photos = {}
local writes, learned, applied = {}, false, {}
local confirms, reviewCancels = {}, 0
local paths = { '/test/Restaurant/frame1.jpg', '/test/Restaurant/frame2.jpg', '/test/Restaurant/frame3.jpg', '/test/Restaurant/frame4.CR3' }
-- Keywords already on each photo, as Lightroom's Keyword Tags panel lists them.
local formattedMetadata = {
    keywordTags = '27137, 1297960, Hotel, Meeting Room, Ramada Plaza Rize, saleh mostafa, Wyndham - EMEA',
    creator = 'Saleh Mostafa',
    copyright = '© 2025 Saleh Mostafa',
}
for i = 1, #paths do
    photos[i] = {
        getRawMetadata = function() return paths[i] end,
        getFormattedMetadata = function(_, key) catalogRead(); return formattedMetadata[key] end,
        setRawMetadata = function(_, key, value)
            -- Photo 3 simulates a Lightroom version that refuses the native Alt Text field.
            if i == 3 and key == 'altTextAccessibility' then error('Unknown key: altTextAccessibility') end
            writes[#writes + 1] = { i, key, value }
        end,
        setPropertyForPlugin = function() end,
        addKeyword = function(_, keyword) applied[i] = applied[i] or {}; table.insert(applied[i], keyword) end,
    }
end
-- Mirrors LrCatalog:createKeyword: an existing keyword is returned only with returnExisting.
local existingKeywords = { ['restaurant interior'] = true }
local created = 0
local factory = setmetatable({}, { __index = function(_, kind)
    return function(_, spec, extra)
        if kind == 'control_spacing' or kind == 'label_spacing' then return 6 end
        assert(type(spec) == 'table' and spec.width_in_chars == nil, kind .. ' uses width_in_chars; dialogs need fixed point widths')
        assert(kind ~= 'combo_box' and not (kind == 'edit_field' and (spec.value == 'geminiModel' or spec.value == 'openaiModel')), 'model must not be free text')
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
    if missingKeyRun then
        p.provider = 'openai' -- no OpenAI key saved
        p.projectContext = 'Kept project facts'
        return 'ok'
    end
    if dialogs == 1 then
        assert(p.provider == 'gemini')
        assert(findKind(spec.contents, 'popup_menu') >= 3, 'provider and model menus missing from preflight')
        assert(p.analysisPrompt and p.analysisPrompt:find('frame%-specific'))
        assert(p.folderPreview:find('Restaurant', 1, true))
        p.analysisPrompt = p.analysisPrompt .. '\nTest remembered instruction.'
        return 'ok'
    end
    assert(p.title1 == 'Test title' and p.title3 == 'Test title')
    assert(p.selectedSummary:find('3 of 3', 1, true), 'missing live selection summary')
    if reviewCancels == 0 then reviewCancels = 1; return 'cancel' end -- first Cancel is withdrawn at the confirmation
    p.title2 = '   ' -- a cleared title must not wipe the existing catalogue title
    assert(p.caption1 == 'Test caption' and p.altText1 == 'Test alt text', 'caption and alt text must be separate fields')
    assert(p.keywords1 == 'restaurant interior, banquette seating', 'keywords already on the photo must not be suggested again')
    assert(findKind(spec.contents, 'edit_field') == 12, 'expected title, caption, alt text and keyword fields per photo')
    local function findText(node, prefix)
        if type(node) ~= 'table' then return nil end
        if node.kind == 'static_text' and type(node.title) == 'string' and node.title:find(prefix, 1, true) == 1 then return node end
        for _, child in pairs(node) do local found = findText(child, prefix); if found then return found end end
    end
    assert(findText(spec.contents, 'Already on photo: Hotel, Meeting Room, Ramada Plaza Rize'), 'existing keywords were not read')
    assert(not findText(spec.contents, '⚠ Could not read'), 'keyword read reported an error')
    local feedback = assert(findText(spec.contents, 'Strong composition'), 'portfolio feedback missing')
    assert(feedback.height_in_lines >= 4, 'feedback box too short for its text')
    assert(findKind(spec.contents, 'group_box') >= 3, 'missing review rows')
    assert(findKind(spec.contents, 'catalog_photo') == 3, 'missing catalogue previews')
    p.applyRatings = true
    p.score1 = '5'; p.score2 = '4'; p.score3 = '3'
    return 'ok'
 end, message = function(title)
    if not (title:find('no API key', 1, true) or title:find('alt text saved', 1, true)) then error('Unexpected error dialog: ' .. title) end
    table.insert(messages, title)
 end,
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
 LrTasks = { startAsyncTask = function(fn) fn() end, pcall = function(fn, ...) return realPcall(fn, ...) end, sleep = function() end },
 LrView = { osFactory = function() return factory end, bind = function(k) return k end, share = function(k) return { share = k } end },
}
function import(name) return assert(namespaces[name], 'Unsupported namespace ' .. name) end
package.loaded.LearningStore = { get = function() return {} end, remember = function() learned = true end }
local sentContexts, sentPrompts = {}, {}
package.loaded.ProviderClient = { analyse = function(settings, _, context)
    table.insert(sentContexts, context); table.insert(sentPrompts, settings.prompt)
    return { title = 'Test title', keywords = {'restaurant interior', 'banquette seating', 'hotel'}, caption = 'Test caption', altText = 'Test alt text', confidence = .9, portfolio = {score = 3, strengths = {'Strong composition'}, cautions = {'Crop is tight'}} }
end }
prefs.sharedTags = 'Banquette Seating, Test Resort'
_PLUGIN = {}
local realOpen = io.open
io.open = function(path)
    assert(path == 'mock-derivative')
    return { read = function() return 'mock' end, close = function() end }
end
dofile(pluginDir .. 'AnalyzeSelected.lua')
io.open = realOpen
assert(tables == 2 and dialogs == 3 and #sentContexts == 3, 'expected preflight, cancelled review, review and three analyses')
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
local captions, altTexts = 0, 0
for _, write in ipairs(writes) do
    if write[2] == 'caption' then assert(write[3] == 'Test caption'); captions = captions + 1 end
    if write[2] == 'altTextAccessibility' then assert(write[3] == 'Test alt text'); altTexts = altTexts + 1 end
end
assert(captions == 3 and altTexts == 2, 'caption and native Alt Text should be written separately')
assert(#messages == 1 and messages[1]:find('alt text saved', 1, true), 'a refused Alt Text field should be reported once')
messages = {}
local context = sentContexts[1]
assert(context:find('Ramada Plaza Rize', 1, true) and context:find('Meeting Room', 1, true), 'existing keywords should be sent as facts')
assert(not context:find('27137', 1, true) and not context:find('saleh mostafa', 1, true), 'job numbers and the photographer name must not be sent')
assert(context:find('Property name for this photo, taken from its keywords: "Ramada Plaza Rize"', 1, true), 'the property name from the keywords must be named for the model')
assert(sentPrompts[1]:find('Test remembered instruction', 1, true) and sentPrompts[1]:find('OUTPUT RULES', 1, true), 'prompt must end with the fixed output rules')
-- Second run: switching to a provider without a saved key stops before any upload, keeping edits.
missingKeyRun = true
local callsBefore = #sentContexts
dofile(pluginDir .. 'AnalyzeSelected.lua')
assert(#messages == 1 and #sentContexts == callsBefore, 'missing key should stop before analysis')
assert(prefs.provider == 'openai' and prefs.projectContext == 'Kept project facts', 'preflight edits should be kept')
print('PASS: separate title/caption/alt text, existing keywords as facts minus IDs and credit, no duplicate suggestions, native Alt Text with fallback notice, missing-key guard keeps edits and sends nothing; contexts, RAW skipped with consent, prompt persistence, catalog previews, cancel confirmation, three rows, existing keywords reused, blank title preserved, rating opt-in, native colour assignment')
