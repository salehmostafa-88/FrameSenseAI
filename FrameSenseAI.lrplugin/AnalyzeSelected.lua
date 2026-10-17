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
local LrSystemInfo = import 'LrSystemInfo'
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

local function keySaved(provider)
    return Util.trim(prefs[provider .. 'ApiKey']) ~= ''
end

local function preflight(photos, context)
    local f = LrView.osFactory()
    local bind, share = LrView.bind, LrView.share
    local property = LrBinding.makePropertyTable(context)
    property.provider = prefs.provider
    property.geminiModel = prefs.geminiModel
    property.openaiModel = prefs.openaiModel
    property.learningProfile = prefs.learningProfile
    property.projectContext = prefs.projectContext
    property.sharedTags = prefs.sharedTags
    property.folderHints = prefs.folderHints
    property.analysisPrompt = prefs.analysisPrompt or Defaults.defaultPrompt
    property.folderPreview = selectedFolderPreview(photos)
    property.showAdvanced = prefs.showAdvanced
    property.saveTitle = prefs.saveTitle
    property.saveKeywords = prefs.saveKeywords
    property.saveCaption = prefs.saveCaption
    property.saveAltText = prefs.saveAltText
    property.useExistingKeywords = prefs.useExistingKeywords
    property.generatePortfolio = prefs.generatePortfolio

    -- Fixed point widths keep the dialog well inside a 1280-point laptop screen.
    local fieldWidth = 460
    local function help(title, message)
        return f:push_button { title = '?', width = 24, action = function() LrDialogs.message(title, message, 'info') end }
    end
    local function label(title)
        return f:static_text { title = title, alignment = 'right', width = share 'fsLabel' }
    end
    local function indented(view)
        return f:row { f:static_text { title = '', width = share 'fsLabel' }, view }
    end
    local learningSummary = bind {
        key = 'learningProfile',
        transform = function(profile)
            if Util.trim(profile) == '' then return 'Enter a name to remember your approved keywords for next time.' end
            local count = #LearningStore.get(profile)
            if count == 0 then return 'New name: approved keywords will be remembered after you save.' end
            return count .. ' approved keywords remembered for this name.'
        end,
    }
    local keyStatus = bind {
        key = 'provider',
        transform = function(provider)
            local info = Defaults.providerInfo[provider]
            if keySaved(provider) then return '✓ ' .. info.keyName .. ' saved.' end
            return '⚠ No ' .. info.keyName .. ' saved. Add it in File → Plug-in Manager → FrameSense AI.'
        end,
    }

    local dialog = f:column {
        bind_to_object = property,
        spacing = f:control_spacing(),
        f:group_box { title = 'AI model for this batch', fill_horizontal = 1,
            f:column { spacing = f:control_spacing(),
                f:row {
                    label('AI provider'),
                    f:popup_menu { value = bind 'provider', items = Defaults.providers, width = fieldWidth },
                },
                f:row {
                    label('Model'),
                    f:view { place = 'overlapping',
                        f:popup_menu { value = bind 'geminiModel', items = Defaults.modelItems('gemini'), width = fieldWidth, visible = LrBinding.keyEquals('provider', 'gemini') },
                        f:popup_menu { value = bind 'openaiModel', items = Defaults.modelItems('openai'), width = fieldWidth, visible = LrBinding.keyEquals('provider', 'openai') },
                    },
                    f:push_button { title = '?', width = 24, action = function()
                        LrDialogs.message('Model and cost', Defaults.pricingSummary(property.provider) .. '\n\nEstimates are rough: about 2,000 input and 1,000 output tokens per photo. Your provider dashboard is the authoritative source for cost.', 'info')
                    end },
                },
                indented(f:static_text { title = keyStatus, width = fieldWidth }),
            },
        },
        f:group_box { title = 'Project details — used for all ' .. #photos .. ' photos', fill_horizontal = 1,
            f:column { spacing = f:control_spacing(),
                f:row {
                    label('Project / property name'),
                    f:edit_field { value = bind 'learningProfile', width = fieldWidth },
                    help('Project / property name', 'Use one stable name for this property or assignment. Approved keyword corrections are remembered locally under this name.'),
                },
                indented(f:static_text { title = learningSummary, width = fieldWidth }),
                f:row {
                    label('Confirmed facts'),
                    f:edit_field { value = bind 'projectContext', width = fieldWidth, height_in_lines = 3 },
                    help('Confirmed facts', 'Facts you want used, such as the property name, location, official venue names or design information. FrameSense will not infer these facts from appearance.'),
                },
                f:row {
                    label('Existing keywords'),
                    f:checkbox { value = bind 'useExistingKeywords', title = 'Use each photo’s keywords as confirmed facts' },
                    help('Existing keywords', 'Sends the keywords already on each photo so the AI can take the property, brand and location names from them (for example "Ramada by Wyndham Riyadh King Fahd Road", "Riyadh") and avoid suggesting them again.\n\nPurely numeric keywords such as job numbers, and your own Creator / Copyright name, are never sent.'),
                },
                f:row {
                    label('Keywords for every photo'),
                    f:edit_field { value = bind 'sharedTags', width = fieldWidth },
                    help('Keywords for every photo', 'Optional confirmed keywords added to every saved photo in this batch, separated by commas.'),
                },
                f:row {
                    label('Folder names'),
                    f:checkbox { value = bind 'folderHints', title = 'Use as hints:' },
                    f:static_text { title = bind 'folderPreview', enabled = bind 'folderHints', width = fieldWidth - 100, height_in_lines = 2 },
                    help('Folder-name hints', 'Sends only the folder and parent-folder names shown here, never the full path. The AI uses them only when they match the photo.'),
                },
            },
        },
        f:group_box { title = 'What to create', fill_horizontal = 1,
            f:row {
                f:checkbox { value = bind 'saveTitle', title = 'Title' },
                f:checkbox { value = bind 'saveKeywords', title = 'Keywords' },
                f:checkbox { value = bind 'saveCaption', title = 'Caption' },
                f:checkbox { value = bind 'saveAltText', title = 'Alt text' },
                f:checkbox { value = bind 'generatePortfolio', title = 'Portfolio rating' },
                help('What to create', 'Title — one line for under the photo on your website: "Space - Property, City, Country".\n\nCaption — a ready-to-post sentence or two for sharing the photo online.\n\nAlt text — a plain description for search engines and screen readers, saved to Lightroom’s Alt Text field.\n\nKeywords — new, frame-specific keywords not already on the photo.\n\nPortfolio rating — a suggestion from the visible image, not a full-resolution technical check. Stars and colour labels change only if you turn that on in the review.'),
            },
        },
        f:checkbox { value = bind 'showAdvanced', title = 'Show analysis prompt' },
        f:group_box { title = 'Analysis prompt', visible = bind 'showAdvanced', fill_horizontal = 1,
            f:column { spacing = f:control_spacing(),
                f:edit_field { value = bind 'analysisPrompt', width = fieldWidth + 180, height_in_lines = 10 },
                f:row {
                    f:push_button { title = 'Restore standard prompt', action = function() property.analysisPrompt = Defaults.defaultPrompt end },
                    f:static_text { title = 'Edit only to change the output rules. Your edits are remembered.' },
                },
            },
        },
        f:static_text { title = 'Privacy: a temporary 1600px JPEG copy without metadata and its filename are sent, plus the facts, folder names and existing keywords you allow above. Folder paths and GPS are never sent.', width = fieldWidth + 180, height_in_lines = 2 },
    }
    if LrDialogs.presentModalDialog { title = 'FrameSense AI — analyse ' .. #photos .. ' photo' .. (#photos == 1 and '' or 's'), contents = dialog, actionVerb = 'Analyse' } ~= 'ok' then return nil end

    prefs.provider = property.provider
    prefs.geminiModel = property.geminiModel
    prefs.openaiModel = property.openaiModel
    prefs.learningProfile = Util.trim(property.learningProfile)
    prefs.projectContext = Util.trim(property.projectContext)
    prefs.sharedTags = property.sharedTags or ''
    prefs.folderHints = property.folderHints and true or false
    prefs.analysisPrompt = Util.trim(property.analysisPrompt)
    if prefs.analysisPrompt == '' then prefs.analysisPrompt = Defaults.defaultPrompt end
    prefs.showAdvanced = property.showAdvanced and true or false
    prefs.saveTitle = property.saveTitle and true or false
    prefs.saveKeywords = property.saveKeywords and true or false
    prefs.saveCaption = property.saveCaption and true or false
    prefs.saveAltText = property.saveAltText and true or false
    prefs.useExistingKeywords = property.useExistingKeywords and true or false
    prefs.generatePortfolio = property.generatePortfolio and true or false
    -- Choices above are saved first, so nothing typed is lost when the key is missing.
    if not keySaved(prefs.provider) then
        LrDialogs.message('FrameSense AI — no API key', 'Add your ' .. Defaults.providerInfo[prefs.provider].keyName .. ' in File → Plug-in Manager → FrameSense AI, then run the analysis again. Your project details have been kept.', 'warning')
        return nil
    end
    if not (prefs.saveTitle or prefs.saveKeywords or prefs.saveCaption or prefs.saveAltText or prefs.generatePortfolio) then
        LrDialogs.message('FrameSense AI — nothing to create', 'Tick at least one item under What to create.', 'warning')
        return nil
    end
    return {
        provider = prefs.provider, geminiModel = prefs.geminiModel, openaiModel = prefs.openaiModel,
        geminiApiKey = prefs.geminiApiKey, openaiApiKey = prefs.openaiApiKey,
        temperature = prefs.temperature, prompt = Defaults.fullPrompt(prefs.analysisPrompt),
    }
end

-- Catalog reads can yield, and a plain pcall cannot be yielded across in Lightroom's Lua 5.1:
-- it fails with "attempt to yield across metamethod/C-call boundary" and the value is lost.
-- LrTasks.pcall is the yield-safe form. Returns the value, or '' plus the error.
local function formatted(photo, field)
    local ok, value = LrTasks.pcall(function() return photo:getFormattedMetadata(field) end)
    if not ok then return '', tostring(value) end
    return type(value) == 'string' and value or ''
end

-- Keyword names straight from the LrKeyword objects, used when the formatted list is empty.
local function keywordNames(photo)
    local ok, keywords = LrTasks.pcall(function() return photo:getRawMetadata('keywords') end)
    if not ok then return {}, tostring(keywords) end
    local names = {}
    for _, keyword in ipairs(type(keywords) == 'table' and keywords or {}) do
        local named, name = LrTasks.pcall(function() return keyword:getName() end)
        if named and type(name) == 'string' then table.insert(names, name) end
    end
    return names
end

-- The photo's own keywords, minus job numbers / IDs and the photographer's own name,
-- which are useless to the AI and should never reach a title or caption.
-- Also returns an error message when the keywords could not be read, so the review can say so.
local function existingKeywords(photo)
    local credits = {}
    for _, field in ipairs { 'creator', 'copyright' } do
        local credit = string.lower(Util.trim(formatted(photo, field):gsub('©', ''):gsub('%(c%)', ''):gsub('[Cc]opyright', ''):gsub('[%d%p]', ' '):gsub('%s+', ' ')))
        if credit ~= '' then credits[credit] = true end
    end
    local tags, readError = formatted(photo, 'keywordTags')
    local terms = Util.split(tags, ',')
    if #terms == 0 then
        local fallbackError
        terms, fallbackError = keywordNames(photo)
        if #terms > 0 then readError = nil else readError = readError or fallbackError end
    end
    local result = {}
    for _, term in ipairs(terms) do
        if not term:match('^[%d%p%s]+$') and not credits[string.lower(term)] then table.insert(result, term) end
    end
    return Util.unique(result), readError
end

local function withoutExisting(keywords, existing)
    local seen, result = {}, {}
    for _, term in ipairs(existing or {}) do seen[string.lower(term)] = true end
    for _, term in ipairs(keywords or {}) do
        if not seen[string.lower(term)] then table.insert(result, term) end
    end
    return result
end

local function makeContext(photo, photoPath, existing)
    local pieces = {
        'Analyse this JPEG for factual, frame-specific Lightroom metadata.',
        'Filename: ' .. Util.leaf(photoPath),
    }
    if prefs.projectContext ~= '' then table.insert(pieces, 'Photographer-confirmed facts for this project: ' .. prefs.projectContext) end
    if prefs.useExistingKeywords and #existing > 0 then
        table.insert(pieces, 'Existing keywords already on this photo (photographer-confirmed; do not repeat them as new keywords): ' .. table.concat(existing, ', '))
        local property = Util.propertyName(existing)
        if property then
            table.insert(pieces, 'Property name for this photo, taken from its keywords: "' .. property .. '". Use this exact name in the title and in the caption; use it in the alt text too when it fits.')
        end
    end
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

-- Keeps the review dialog, including its buttons, on a small laptop screen.
local function reviewSize()
    local width, height = 1060, 700
    local ok, displays = pcall(LrSystemInfo.displayInfo)
    local display = ok and type(displays) == 'table' and displays[1]
    if display and display.width and display.height then
        width = math.max(760, math.min(width, display.width - 100))
        height = math.max(360, math.min(height, display.height - 280))
    end
    return width, height
end

local function review(records, context, failureCount)
    local f = LrView.osFactory()
    local bind = LrView.bind
    local property = LrBinding.makePropertyTable(context)
    property.applyRatings = prefs.generatePortfolio and prefs.applyRatings and true or false
    local function updateSelectedCount()
        local selected = 0
        for i = 1, #records do if property['enabled' .. i] then selected = selected + 1 end end
        property.selectedSummary = selected .. ' of ' .. #records .. ' photos will be saved.'
    end
    -- Live character counters: ideal is advice, limit is where saving shortens the text.
    local function counter(key, ideal, limit)
        return bind { key = key, transform = function(value)
            local count = Util.length(Util.trim(value))
            if count > limit then return count .. ' / ' .. limit .. ' — will be shortened' end
            if count > ideal then return count .. ' characters — aim for ' .. ideal end
            return count .. ' / ' .. ideal
        end }
    end
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
        property['caption' .. i] = record.caption
        property['altText' .. i] = record.altText
        property['score' .. i] = tostring(record.portfolio.score)
        property:addObserver('enabled' .. i, updateSelectedCount)
    end
    updateSelectedCount()
    local width, height = reviewSize()
    local intro = 'Check and correct each suggestion, untick any photo you do not want saved, then choose Save.'
    if (failureCount or 0) > 0 then intro = intro .. '\n' .. failureCount .. ' photo(s) could not be analysed; details are shown after this review.' end
    local fieldWidth, sideWidth = 440, 220

    -- Views are rebuilt for each presentation; all edits live in the property table.
    local function buildContents()
        local rows = {}
        for i, record in ipairs(records) do
            local reason = table.concat(record.portfolio.strengths or {}, '; ')
            if reason == '' then reason = record.portfolio.recommendedUse or 'Review the visible composition and usefulness.' end
            if #(record.portfolio.cautions or {}) > 0 then reason = reason .. '\nCheck: ' .. table.concat(record.portfolio.cautions, '; ') end
            -- Only the fields chosen under What to create are shown.
            local fields = { spacing = f:label_spacing() }
            local function heading(title, count)
                table.insert(fields, f:row {
                    f:static_text { title = title, width = fieldWidth - 190 },
                    f:static_text { title = count or '', alignment = 'right', width = 190 },
                })
            end
            if prefs.saveTitle then
                heading('Title — one line for your website', counter('title' .. i, 90, math.huge))
                table.insert(fields, f:edit_field { value = bind('title' .. i), width = fieldWidth })
            end
            if prefs.saveCaption then
                heading('Caption — to post with the photo', counter('caption' .. i, 300, 500))
                table.insert(fields, f:edit_field { value = bind('caption' .. i), width = fieldWidth, height_in_lines = 3 })
            end
            if prefs.saveAltText then
                heading('Alt text — for search engines', counter('altText' .. i, 125, 250))
                table.insert(fields, f:edit_field { value = bind('altText' .. i), width = fieldWidth, height_in_lines = 3 })
            end
            if prefs.saveKeywords then
                heading('New keywords (comma-separated)')
                table.insert(fields, f:edit_field { value = bind('keywords' .. i), width = fieldWidth, height_in_lines = 2 })
            end
            if record.propertyName and (prefs.saveTitle or prefs.saveCaption or prefs.saveAltText) then
                local used = (record.title .. ' ' .. record.caption .. ' ' .. record.altText):lower()
                if not used:find(record.propertyName:lower(), 1, true) then
                    table.insert(fields, f:static_text { title = '⚠ Property name "' .. record.propertyName .. '" from the keywords is not in the text. Add it if it belongs.', width = fieldWidth, height_in_lines = 2 })
                end
            end
            if record.keywordError then
                table.insert(fields, f:static_text { title = '⚠ Could not read this photo’s keywords, so they were not used: ' .. record.keywordError, width = fieldWidth, height_in_lines = 2 })
            end
            if #(record.existingKeywords or {}) > 0 then
                table.insert(fields, f:static_text { title = 'Already on photo: ' .. table.concat(record.existingKeywords, ', '), width = fieldWidth, height_in_lines = 2, enabled = false })
            end
            local side = { spacing = f:label_spacing(), f:static_text { title = confidenceText(record.confidence), width = sideWidth } }
            if prefs.generatePortfolio then
                table.insert(side, f:static_text { title = 'Portfolio rating' })
                table.insert(side, f:popup_menu { value = bind('score' .. i), items = ratingItems, width = sideWidth })
                table.insert(side, f:checkbox { value = bind('ratingEnabled' .. i), enabled = bind 'applyRatings', title = 'Set stars & colour label' })
                -- About 34 characters fit a line at this width; size the box to the whole text.
                local lines = 0
                for paragraph in (reason .. '\n'):gmatch('(.-)\n') do lines = lines + math.max(1, math.ceil(Util.length(paragraph) / 34)) end
                table.insert(side, f:static_text { title = reason, width = sideWidth, height_in_lines = math.max(4, lines + 1) })
            end
            table.insert(rows, f:group_box {
                title = record.filename, fill_horizontal = 1,
                f:row {
                    f:column {
                        f:checkbox { value = bind('enabled' .. i), title = 'Save this photo' },
                        f:catalog_photo { photo = record.photo, width = 260, height = 173, frame_width = 1 },
                    },
                    f:column(fields),
                    f:column(side),
                },
            })
        end
        local toolbar = {
            f:push_button { title = 'Select all', action = function() for i = 1, #records do property['enabled' .. i] = true end end },
            f:push_button { title = 'Select none', action = function() for i = 1, #records do property['enabled' .. i] = false end end },
            f:static_text { title = bind 'selectedSummary', width = 200 },
        }
        if prefs.generatePortfolio then
            table.insert(toolbar, f:spacer { width = 20 })
            table.insert(toolbar, f:checkbox { value = bind 'applyRatings', title = 'Also set Lightroom stars & colour labels' })
            table.insert(toolbar, f:push_button { title = '?', width = 24, action = function() LrDialogs.message('Lightroom stars & colour labels', 'When ticked, each photo whose "Set stars & colour label" box is also ticked gets:\n\n5 stars + Blue — Hero\n4 stars + Green — Portfolio\n3 stars + Yellow — Supporting\n2 stars + Red — Needs review\n1 star + no label — Reject candidate\n\nLeave it unticked to keep existing ratings and labels. The portfolio rating is still saved in the FrameSense metadata panel. It is a suggestion from the visible image, not a full-resolution technical check.', 'info') end })
        end
        return f:column {
            bind_to_object = property,
            spacing = f:control_spacing(),
            f:static_text { title = intro, width = width, height_in_lines = (failureCount or 0) > 0 and 2 or 1 },
            f:row(toolbar),
            f:scrolled_view { width = width, height = height, horizontal_scroller = true, vertical_scroller = true, f:column(rows) },
        }
    end
    -- The analysis has already been paid for, so Cancel/Esc asks before discarding it.
    while LrDialogs.presentModalDialog { title = 'FrameSense AI — review ' .. #records .. ' photos', contents = buildContents(), actionVerb = 'Save', cancelVerb = 'Discard…' } ~= 'ok' do
        if LrDialogs.confirm('Discard all ' .. #records .. ' AI suggestions?', 'Nothing will be saved to the catalogue. Running the analysis again will send the photos to the provider again.', 'Discard', 'Back to review') == 'ok' then return nil end
    end
    prefs.applyRatings = prefs.generatePortfolio and property.applyRatings and true or false
    local labels = { ['1'] = 'Reject candidate', ['2'] = 'Needs review', ['3'] = 'Supporting', ['4'] = 'Portfolio', ['5'] = 'Hero' }
    for i, record in ipairs(records) do
        record.enabled = property['enabled' .. i] and true or false
        record.ratingEnabled = property['ratingEnabled' .. i] and true or false
        record.applyRating = prefs.applyRatings and record.ratingEnabled
        record.title = Util.trim(property['title' .. i])
        record.keywords = withoutExisting(Util.unique(Util.split(property['keywords' .. i], ',')), record.existingKeywords)
        record.caption = Util.clip(property['caption' .. i], 500)
        record.altText = Util.clip(property['altText' .. i], 250)
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
    local keywords = {}
    local altTextFallbacks = 0
    -- returnExisting = true: without it createKeyword returns false for any keyword
    -- already in the catalogue, and that keyword was silently not applied.
    local function keywordFor(term)
        local key = string.lower(term)
        if keywords[key] == nil then keywords[key] = catalog:createKeyword(term, {}, true, nil, true) or false end
        return keywords[key]
    end
    catalog:withWriteAccessDo('Save FrameSense AI metadata', function()
        for _, record in ipairs(records) do
            if record.enabled then
                -- A blank field never overwrites what is already in the catalogue.
                if prefs.saveTitle and record.title ~= '' then record.photo:setRawMetadata('title', record.title) end
                if prefs.saveCaption and record.caption ~= '' then record.photo:setRawMetadata('caption', record.caption) end
                if prefs.saveAltText and record.altText ~= '' then
                    record.photo:setPropertyForPlugin(_PLUGIN, 'formatAltText', record.altText)
                    -- Lightroom's own Alt Text field (IPTC accessibility, exported with the file).
                    -- Older Lightroom versions refuse this key; the FrameSense field above still holds it.
                    if not LrTasks.pcall(function() record.photo:setRawMetadata('altTextAccessibility', record.altText) end) then
                        altTextFallbacks = altTextFallbacks + 1
                    end
                end
                if prefs.generatePortfolio then
                    record.photo:setPropertyForPlugin(_PLUGIN, 'portfolioScore', tostring(record.portfolio.score))
                    record.photo:setPropertyForPlugin(_PLUGIN, 'portfolioLabel', record.portfolio.label)
                    record.photo:setPropertyForPlugin(_PLUGIN, 'portfolioUse', record.portfolio.recommendedUse or '')
                end
                record.photo:setPropertyForPlugin(_PLUGIN, 'lastRun', os.date('%Y-%m-%d %H:%M'))
                if prefs.saveKeywords then
                    local terms = Util.unique(record.keywords)
                    for _, term in ipairs(Util.split(prefs.sharedTags, ',')) do table.insert(terms, term) end
                    for _, term in ipairs(Util.unique(terms)) do
                        local keyword = keywordFor(term)
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
    if prefs.saveKeywords then LearningStore.remember(prefs.learningProfile, records) end
    if altTextFallbacks > 0 then
        LrDialogs.message('FrameSense AI — alt text saved in the FrameSense panel', 'This Lightroom version did not let the plug-in fill its Alt Text field (Lightroom Classic 13.2 or later is needed), so the alt text for ' .. altTextFallbacks .. ' photo(s) is in the Metadata panel under "Format image description / alt text". Everything else was saved.', 'info')
    end
end

local maxBatch = 50

local function namesList(names)
    local shown = {}
    for i = 1, math.min(#names, 8) do shown[i] = '• ' .. names[i] end
    if #names > 8 then table.insert(shown, '• …and ' .. (#names - 8) .. ' more') end
    return table.concat(shown, '\n')
end

-- Returns the eligible photos, or nil when there is nothing to do or the user cancels.
-- Ineligible photos are skipped with the user's consent instead of blocking the whole batch.
local function validate(photos)
    if #photos == 0 then LrDialogs.message('FrameSense AI', 'Select one or more JPEG images in the Library first.', 'warning'); return nil end
    local eligible, notJpeg, notLocal = {}, {}, {}
    for _, photo in ipairs(photos) do
        local path = photo:getRawMetadata('path') or ''
        if not Util.isJpeg(path) then table.insert(notJpeg, Util.leaf(path))
        elseif not Util.localFileExists(path) then table.insert(notLocal, Util.leaf(path))
        else table.insert(eligible, photo) end
    end
    local problems = {}
    if #notJpeg > 0 then table.insert(problems, #notJpeg .. ' not JPEG (RAW and other formats are intentionally skipped):\n' .. namesList(notJpeg)) end
    if #notLocal > 0 then table.insert(problems, #notLocal .. ' not available locally (make them available offline in Dropbox first):\n' .. namesList(notLocal)) end
    if #eligible == 0 then
        LrDialogs.message('FrameSense AI — nothing to analyse', table.concat(problems, '\n\n'), 'warning')
        return nil
    end
    local notes = {}
    if #problems > 0 then table.insert(notes, table.concat(problems, '\n\n')) end
    if #eligible > maxBatch then
        table.insert(notes, #eligible .. ' JPEGs are eligible, but a reviewed batch holds at most ' .. maxBatch .. '. Only the first ' .. maxBatch .. ' will be analysed.')
        for i = #eligible, maxBatch + 1, -1 do table.remove(eligible, i) end
    end
    if #notes > 0 then
        local skipped = #photos - #eligible
        local answer = LrDialogs.confirm(skipped .. ' of ' .. #photos .. ' selected photos will be skipped', table.concat(notes, '\n\n'), 'Continue with ' .. #eligible .. ' JPEG' .. (#eligible == 1 and '' or 's'), 'Cancel')
        if answer ~= 'ok' then return nil end
    end
    return eligible
end

LrTasks.startAsyncTask(function()
    LrFunctionContext.callWithContext('FrameSenseAnalyse', function(context)
        local photos = validate(LrApplication.activeCatalog():getTargetPhotos())
        if not photos then return end
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
                local existing, keywordError = existingKeywords(photo)
                local analysis = ProviderClient.analyse(settings, base64, makeContext(photo, path, existing))
                analysis.existingKeywords = existing
                analysis.keywordError = keywordError
                analysis.propertyName = Util.propertyName(existing)
                analysis.keywords = withoutExisting(analysis.keywords, existing)
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
            local reviewed = review(records, context, #failures)
            if reviewed then save(reviewed) end
        end
        deletePreviews(records)
        if #failures > 0 then LrDialogs.message('FrameSense AI — some images were not analysed', table.concat(failures, '\n\n'), 'warning') end
        if #records == 0 and #failures == 0 then LrDialogs.message('FrameSense AI', 'No images were analysed.') end
    end)
end)
