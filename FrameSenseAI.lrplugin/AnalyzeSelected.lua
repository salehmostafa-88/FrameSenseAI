local LrApplication = import 'LrApplication'
local LrBinding = import 'LrBinding'
local LrDialogs = import 'LrDialogs'
local LrExportSession = import 'LrExportSession'
local LrFileUtils = import 'LrFileUtils'
local LrFunctionContext = import 'LrFunctionContext'
local LrPathUtils = import 'LrPathUtils'
local LrPrefs = import 'LrPrefs'
local LrProgressScope = import 'LrProgressScope'
local LrStringUtils = import 'LrStringUtils'
local LrTasks = import 'LrTasks'
local LrView = import 'LrView'

local Defaults = require 'Defaults'
local LearningStore = require 'LearningStore'
local ProviderClient = require 'ProviderClient'
local Util = require 'Util'

local prefs = LrPrefs.prefsForPlugin()
Defaults.initialize(prefs)

local function selectedFolderPreview(photos)
    local hints = {}
    for _, photo in ipairs(photos) do
        for _, hint in ipairs(Util.folderHints(photo:getRawMetadata('path') or '')) do table.insert(hints, hint) end
    end
    hints = Util.unique(hints)
    if #hints == 0 then return 'No useful immediate folder or parent-folder labels were found.' end
    return table.concat(hints, '  •  ')
end

local function preflight(photos, context)
    local f = LrView.osFactory()
    local bind = LrView.bind
    local property = LrBinding.makePropertyTable(context)
    property.provider = prefs.provider
    property.geminiModel = prefs.geminiModel
    property.openaiModel = prefs.openaiModel
    property.temperature = prefs.temperature
    property.learningProfile = prefs.learningProfile
    property.projectContext = prefs.projectContext
    property.sharedTags = prefs.sharedTags
    property.folderHints = prefs.folderHints
    property.batchDelayMs = prefs.batchDelayMs
    property.analysisPrompt = prefs.analysisPrompt or Defaults.defaultPrompt
    property.folderPreview = selectedFolderPreview(photos)
    property.showAdvanced = prefs.showAdvanced
    property.saveTitle = prefs.saveTitle
    property.saveKeywords = prefs.saveKeywords
    property.saveDescription = prefs.saveDescription
    property.generatePortfolio = prefs.generatePortfolio
    property.learningSummary = tostring(#LearningStore.get(prefs.learningProfile)) .. ' approved vocabulary terms remembered locally'

    local labelWidth = 22
    local function help(title, message)
        return f:push_button { title = '?', width = 24, action = function() LrDialogs.message(title, message, 'info') end }
    end

    local dialog = f:column {
        bind_to_object = property,
        spacing = f:control_spacing(),
        f:static_text { title = 'Add project facts once. FrameSense uses them for all ' .. #photos .. ' selected photos.' },
        f:group_box { title = 'Project details',
            f:column { spacing = f:control_spacing(),
                f:row {
                    f:static_text { title = 'Project / property name', width_in_chars = labelWidth },
                    f:edit_field { value = bind 'learningProfile', width_in_chars = 66 },
                    help('Project / property name', 'Use one stable name for this property or assignment. Approved keyword corrections are remembered locally under this name.'),
                },
                f:row {
                    f:static_text { title = 'Project context', width_in_chars = labelWidth, alignment = 'right' },
                    f:edit_field { value = bind 'projectContext', width_in_chars = 78, height_in_lines = 3 },
                    help('Project context', 'Confirmed facts such as property, location, official venue names or design information. FrameSense will not infer these facts from appearance.'),
                },
                f:row {
                    f:static_text { title = '', width_in_chars = labelWidth },
                    f:checkbox { value = bind 'folderHints', title = 'Use folder names as hints' },
                    help('Folder-name hints', 'Uses only the immediate folder and its parent as optional naming hints. Full file paths are never sent.'),
                },
                f:row {
                    f:static_text { title = 'Detected folder names', width_in_chars = labelWidth },
                    f:static_text { title = bind 'folderPreview', width_in_chars = 78, height_in_lines = 2 },
                },
                f:row {
                    f:static_text { title = 'Shared keywords', width_in_chars = labelWidth },
                    f:edit_field { value = bind 'sharedTags', width_in_chars = 66 },
                    help('Shared keywords', 'Optional confirmed keywords added to every saved image in this batch, separated by commas.'),
                },
            },
        },
        f:group_box { title = 'What to create',
            f:row {
                f:checkbox { value = bind 'saveTitle', title = 'Title' },
                f:checkbox { value = bind 'saveKeywords', title = 'Keywords' },
                f:checkbox { value = bind 'saveDescription', title = 'Image description' },
                f:checkbox { value = bind 'generatePortfolio', title = 'Portfolio suggestion' },
                help('Portfolio suggestion', 'A visible-image selection aid, not a full-resolution technical-quality assessment. You remain in control of Lightroom ratings.'),
            },
        },
        f:static_text { title = bind 'learningSummary' },
        f:checkbox { value = bind 'showAdvanced', title = 'Show advanced settings' },
        f:group_box { title = 'Advanced settings', visible = bind 'showAdvanced',
            f:column { spacing = f:control_spacing(),
                f:row { f:static_text { title = 'AI provider', width_in_chars = labelWidth }, f:popup_menu { value = bind 'provider', items = { { title = 'Google Gemini', value = 'gemini' }, { title = 'OpenAI', value = 'openai' } } } },
                f:row { f:static_text { title = 'Gemini model', width_in_chars = labelWidth }, f:edit_field { value = bind 'geminiModel', width_in_chars = 42 } },
                f:row { f:static_text { title = 'OpenAI model', width_in_chars = labelWidth }, f:edit_field { value = bind 'openaiModel', width_in_chars = 42 } },
                f:row { f:static_text { title = 'Creativity', width_in_chars = labelWidth }, f:static_text { title = 'Consistent' }, f:slider { value = bind 'temperature', min = 0, max = 1, width_in_chars = 20 }, f:static_text { title = 'Varied' }, help('Creativity', 'Lower values give more consistent factual wording. Higher values create more variation and may need more correction.') },
                f:row { f:static_text { title = 'Request pace (ms)', width_in_chars = labelWidth }, f:edit_field { value = bind 'batchDelayMs', width_in_chars = 10 } },
                f:row { f:static_text { title = 'Analysis prompt', width_in_chars = labelWidth, alignment = 'right' }, f:edit_field { value = bind 'analysisPrompt', width_in_chars = 82, height_in_lines = 11 }, help('Analysis prompt', 'The detailed instruction sent to the selected AI provider. Edit only when you want to change the output rules.') },
                f:push_button { title = 'Restore standard prompt', action = function() property.analysisPrompt = Defaults.defaultPrompt end },
            },
        },
        f:static_text { title = 'Privacy: only a temporary, metadata-free 1600px JPEG derivative is sent. Original paths, GPS and existing keywords are excluded.' },
    }
    if LrDialogs.presentModalDialog { title = 'FrameSense AI — analyse ' .. #photos .. ' photos', contents = dialog, actionVerb = 'Analyse ' .. #photos .. ' photos' } ~= 'ok' then return nil end

    prefs.provider = property.provider
    prefs.geminiModel = Util.trim(property.geminiModel)
    prefs.openaiModel = Util.trim(property.openaiModel)
    prefs.temperature = math.max(0, math.min(1, tonumber(property.temperature) or 0.2))
    prefs.learningProfile = Util.trim(property.learningProfile)
    prefs.projectContext = Util.trim(property.projectContext)
    prefs.sharedTags = property.sharedTags or ''
    prefs.folderHints = property.folderHints and true or false
    prefs.batchDelayMs = math.max(0, math.min(10000, tonumber(property.batchDelayMs) or 700))
    prefs.analysisPrompt = Util.trim(property.analysisPrompt)
    if prefs.analysisPrompt == '' then prefs.analysisPrompt = Defaults.defaultPrompt end
    prefs.showAdvanced = property.showAdvanced and true or false
    prefs.saveTitle = property.saveTitle and true or false
    prefs.saveKeywords = property.saveKeywords and true or false
    prefs.saveDescription = property.saveDescription and true or false
    prefs.generatePortfolio = property.generatePortfolio and true or false
    return {
        provider = prefs.provider, geminiModel = prefs.geminiModel, openaiModel = prefs.openaiModel,
        geminiApiKey = prefs.geminiApiKey, openaiApiKey = prefs.openaiApiKey,
        temperature = prefs.temperature, prompt = prefs.analysisPrompt,
    }
end

local function makeContext(photo, photoPath)
    local pieces = {
        'Analyse this JPEG for factual, frame-specific Lightroom metadata.',
        'Filename: ' .. Util.leaf(photoPath),
    }
    if prefs.projectContext ~= '' then table.insert(pieces, 'Photographer-approved project context: ' .. prefs.projectContext) end
    if prefs.folderHints then
        local hints = Util.folderHints(photoPath)
        if #hints > 0 then table.insert(pieces, 'Photographer-approved local folder naming hints: ' .. table.concat(hints, ', ') .. '. They are labels only, never a path.') end
    end
    local vocabulary = LearningStore.get(prefs.learningProfile)
    if #vocabulary > 0 then table.insert(pieces, 'Photographer-approved vocabulary from earlier reviewed images in this same learning profile: ' .. table.concat(vocabulary, ', ') .. '. Use only terms that match this frame.') end
    return table.concat(pieces, '\n')
end

local function renderDerivative(photo, context)
    local temp = LrPathUtils.child(LrPathUtils.getStandardFilePath('temp'), 'FrameSenseAI')
    LrFileUtils.createAllDirectories(temp)
    local session = LrExportSession {
        photosToExport = { photo },
        exportSettings = {
            LR_export_destinationType = 'specificFolder', LR_export_destinationPathPrefix = temp,
            LR_export_useSubfolder = false, LR_format = 'JPEG', LR_jpeg_quality = 70,
            LR_size_doConstrain = true, LR_size_maxWidth = 1600, LR_size_maxHeight = 1600,
            LR_metadata_exportMode = 'none', LR_removeLocationMetadata = true,
            LR_collisionHandling = 'rename',
        },
    }
    for _, rendition in session:renditions { stopIfCanceled = true } do
        local ok, pathOrMessage = rendition:waitForRender()
        if not ok then error('Lightroom could not render a temporary JPEG: ' .. tostring(pathOrMessage)) end
        local source = io.open(pathOrMessage, 'rb')
        if not source then error('Could not read temporary JPEG.') end
        local bytes = source:read('*all'); source:close()
        return LrStringUtils.encodeBase64(bytes), pathOrMessage
    end
    error('Lightroom did not render a temporary JPEG.')
end

local function review(records, context)
    local f = LrView.osFactory()
    local bind = LrView.bind
    local property = LrBinding.makePropertyTable(context)
    property.applyRatings = prefs.generatePortfolio and prefs.applyRatings and true or false
    local rows = {}
    local ratingItems = {
        { title = '★★★★★  Hero + Blue', value = '5' },
        { title = '★★★★☆  Portfolio + Green', value = '4' },
        { title = '★★★☆☆  Supporting + Yellow', value = '3' },
        { title = '★★☆☆☆  Needs review + Red', value = '2' },
        { title = '★☆☆☆☆  Reject candidate + No label', value = '1' },
    }
    local function confidenceText(value)
        if value >= 0.8 then return 'High confidence' end
        if value >= 0.55 then return 'Review suggested' end
        return 'Low confidence — check carefully'
    end
    for i, record in ipairs(records) do
        property['enabled' .. i] = true
        property['ratingEnabled' .. i] = true
        property['title' .. i] = record.title
        property['keywords' .. i] = table.concat(record.keywords, ', ')
        property['description' .. i] = record.description
        property['score' .. i] = tostring(record.portfolio.score)
        local reason = table.concat(record.portfolio.strengths or {}, '; ')
        if reason == '' then reason = record.portfolio.recommendedUse or 'Review the visible composition and usefulness.' end
        table.insert(rows, f:group_box {
            title = record.filename,
            f:row {
                f:column {
                    f:checkbox { value = bind('enabled' .. i), title = 'Save metadata' },
                    f:catalog_photo { photo = record.photo, width = 280, height = 187, frame_width = 1 },
                },
                f:column {
                    f:static_text { title = 'Title' }, f:edit_field { value = bind('title' .. i), width_in_chars = 62 },
                    f:static_text { title = 'Frame-specific keywords (comma-separated)' }, f:edit_field { value = bind('keywords' .. i), width_in_chars = 76, height_in_lines = 2 },
                    f:static_text { title = 'Format image description / alt text' }, f:edit_field { value = bind('description' .. i), width_in_chars = 76, height_in_lines = 3 },
                },
                f:column {
                    f:static_text { title = 'Portfolio rating' },
                    f:popup_menu { value = bind('score' .. i), items = ratingItems, enabled = prefs.generatePortfolio, width_in_chars = 29 },
                    f:checkbox { value = bind('ratingEnabled' .. i), enabled = prefs.generatePortfolio, title = 'Update LR rating & label' },
                    f:static_text { title = confidenceText(record.confidence), width_in_chars = 30 },
                    f:static_text { title = reason, width_in_chars = 30, height_in_lines = 4 },
                },
            },
        })
    end
    local contents = f:column {
        bind_to_object = property,
        spacing = f:control_spacing(),
        f:static_text { title = 'Review the suggestions below. Approved edits improve this project’s local vocabulary; they do not train the cloud model.' },
        f:row {
            f:push_button { title = 'Select all metadata', action = function() for i = 1, #records do property['enabled' .. i] = true end end },
            f:push_button { title = 'Select none', action = function() for i = 1, #records do property['enabled' .. i] = false end end },
            f:checkbox { value = bind 'applyRatings', enabled = prefs.generatePortfolio, title = 'Apply Lightroom ratings & labels' },
            f:push_button { title = '?', width = 24, action = function() LrDialogs.message('Lightroom ratings & labels', 'Optional portfolio-suitability suggestions:\n\n5 + Blue — Hero\n4 + Green — Portfolio\n3 + Yellow — Supporting\n2 + Red — Needs review\n1 + no label — Reject candidate\n\nUncheck the master option or an individual image to preserve its existing Lightroom rating and label. This is not a full-resolution technical-quality assessment.', 'info') end },
            f:static_text { title = 'Uncheck to leave existing Lightroom ratings and labels unchanged.' },
        },
        f:scrolled_view { width = 1380, height = 700, horizontal_scroller = false, vertical_scroller = true, f:column(rows) },
        f:static_text { title = #records .. ' of ' .. #records .. ' selected. Saving metadata and applying Lightroom ratings are separate choices.' },
    }
    if LrDialogs.presentModalDialog { title = 'FrameSense AI — review ' .. #records .. ' photos', contents = contents, actionVerb = 'Save selected photos' } ~= 'ok' then return nil end
    prefs.applyRatings = prefs.generatePortfolio and property.applyRatings and true or false
    local labels = { ['1'] = 'Reject candidate', ['2'] = 'Needs review', ['3'] = 'Supporting', ['4'] = 'Portfolio', ['5'] = 'Hero' }
    for i, record in ipairs(records) do
        record.enabled = property['enabled' .. i] and true or false
        record.ratingEnabled = property['ratingEnabled' .. i] and true or false
        record.applyRating = prefs.applyRatings and record.ratingEnabled
        record.title = Util.trim(property['title' .. i])
        record.keywords = Util.unique(Util.split(property['keywords' .. i], ','))
        record.description = Util.clip(property['description' .. i], 255)
        record.altText = record.description
        record.portfolio.score = tonumber(property['score' .. i]) or 3
        record.portfolio.label = labels[property['score' .. i]] or 'Supporting'
    end
    return records
end

local function deletePreviews(records)
    for _, record in ipairs(records or {}) do
        if record.previewPath then
            pcall(LrFileUtils.delete, record.previewPath)
            record.previewPath = nil
        end
    end
end

local function colorForScore(score)
    return ({ [1] = 'none', [2] = 'red', [3] = 'yellow', [4] = 'green', [5] = 'blue' })[score] or 'none'
end

local function save(records)
    local catalog = LrApplication.activeCatalog()
    catalog:withWriteAccessDo('Save FrameSense AI metadata', function()
        for _, record in ipairs(records) do
            if record.enabled then
                if prefs.saveTitle then record.photo:setRawMetadata('title', record.title) end
                if prefs.saveDescription then
                    record.photo:setRawMetadata('caption', record.description)
                    record.photo:setPropertyForPlugin(_PLUGIN, 'formatAltText', record.altText)
                end
                if prefs.generatePortfolio then
                    record.photo:setPropertyForPlugin(_PLUGIN, 'portfolioScore', tostring(record.portfolio.score))
                    record.photo:setPropertyForPlugin(_PLUGIN, 'portfolioLabel', record.portfolio.label)
                    record.photo:setPropertyForPlugin(_PLUGIN, 'portfolioUse', record.portfolio.recommendedUse or '')
                end
                record.photo:setPropertyForPlugin(_PLUGIN, 'lastRun', os.date('%Y-%m-%d %H:%M'))
                if prefs.saveKeywords then
                    for _, term in ipairs(Util.unique(record.keywords)) do
                        local keyword = catalog:createKeyword(term, nil, true)
                        if keyword then record.photo:addKeyword(keyword) end
                    end
                    for _, term in ipairs(Util.split(prefs.sharedTags, ',')) do
                        local keyword = catalog:createKeyword(term, nil, true)
                        if keyword then record.photo:addKeyword(keyword) end
                    end
                end
            end
            if record.applyRating then
                record.photo:setRawMetadata('rating', record.portfolio.score)
                record.photo:setRawMetadata('colorNameForLabel', colorForScore(record.portfolio.score))
            end
        end
    end)
    LearningStore.remember(prefs.learningProfile, records)
end

local function validate(photos)
    if #photos == 0 then LrDialogs.message('FrameSense AI', 'Select one or more JPEG images in the Library first.', 'warning'); return false end
    if #photos > 50 then LrDialogs.message('FrameSense AI', 'Select no more than 50 JPEGs per reviewed batch.', 'warning'); return false end
    for _, photo in ipairs(photos) do
        local path = photo:getRawMetadata('path') or ''
        if not Util.isJpeg(path) then LrDialogs.message('FrameSense AI', 'JPEGs only. RAW and non-JPEG files are intentionally refused.'); return false end
        if not Util.localFileExists(path) then LrDialogs.message('FrameSense AI', 'One selected JPEG is not available locally. Make it offline in Dropbox before analysing.'); return false end
    end
    return true
end

LrTasks.startAsyncTask(function()
    LrFunctionContext.callWithContext('FrameSenseAnalyse', function(context)
        local photos = LrApplication.activeCatalog():getTargetPhotos()
        if not validate(photos) then return end
        local settings = preflight(photos, context)
        if not settings then return end
        local scope = LrProgressScope { title = 'FrameSense AI is analysing selected JPEGs', functionContext = context }
        local records, failures = {}, {}
        for i, photo in ipairs(photos) do
            if scope:isCanceled() then break end
            local path = photo:getRawMetadata('path') or ''
            scope:setPortionComplete(i - 1, #photos)
            scope:setCaption('Analysing ' .. Util.leaf(path) .. ' (' .. i .. ' of ' .. #photos .. ')')
            local previewPath
            local ok, result = LrTasks.pcall(function()
                local base64
                base64, previewPath = renderDerivative(photo, context)
                local analysis = ProviderClient.analyse(settings, base64, makeContext(photo, path))
                pcall(LrFileUtils.delete, previewPath)
                previewPath = nil
                analysis.photo, analysis.filename = photo, Util.leaf(path)
                return analysis
            end)
            if ok then
                table.insert(records, result)
            else
                if previewPath then pcall(LrFileUtils.delete, previewPath) end
                table.insert(failures, Util.leaf(path) .. ': ' .. tostring(result))
            end
            if i < #photos then LrTasks.sleep(prefs.batchDelayMs / 1000) end
        end
        scope:done()
        if #records > 0 then
            local reviewed = review(records, context)
            if reviewed then save(reviewed) end
        end
        deletePreviews(records)
        if #failures > 0 then LrDialogs.message('FrameSense AI — some images were not analysed', table.concat(failures, '\n\n'), 'warning') end
        if #records == 0 and #failures == 0 then LrDialogs.message('FrameSense AI', 'No images were analysed.') end
    end)
end)
