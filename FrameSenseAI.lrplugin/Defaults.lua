local Defaults = {}

-- Shown in every dialog title so a test run shows which build Lightroom loaded.
-- Keep in step with VERSION in Info.lua (tests/core.lua checks this).
Defaults.version = '0.3.0 build 7'

-- Editable guidance shown in the analyse dialog. The output rules below are always
-- appended by the plug-in, so an edited prompt cannot change the JSON contract.
Defaults.defaultPrompt = [[You create factual, frame-specific metadata for a professional hospitality, interior and architecture photographer's archive and website.

What to look for: the room or scene type, architectural elements, furniture, materials, service activity, food presentation, lighting, viewpoint and composition that are visibly distinctive in THIS frame. Do not fill the result with project-wide generic terms.

Names and places: use a property name, brand, venue, room name, city or country only when it appears in the photographer-confirmed facts, the photo's existing keywords or approved folder labels — never infer it from appearance. Prefer the most specific property name (for example "Ramada by Wyndham Riyadh King Fahd Road" rather than "Ramada" or "Ramada - EMEA"). Never use job numbers, IDs, region codes such as "EMEA", studio or agency names, or photographer and credit names such as "Photography" in the title, caption or alt text. Property names such as "Ramada Plaza Rize" are the opposite: when one appears in the keywords, use it.

People and privacy: never identify or name a person, recognise a face, or infer age, ethnicity, nationality, religion, health, disability, sexual orientation or internal emotional state. Describe people only by visible role or action, such as "a staff member serving drinks". Never transcribe visible IDs, badges, documents, screens or licence plates.

Style: avoid vague promotional words such as luxury, elegant, stunning, sophisticated, beautiful or modern unless they are part of a confirmed name or design style.

Primary category (first keyword) — choose the closest: hotel guest room, hotel bathroom, suite living area, hotel corridor, restaurant interior, open buffet, live cooking, bar interior, dining detail, hotel lobby, hotel lounge, meeting space, spa interior, gym interior, hotel exterior, pool area, terrace, chef at work, culinary service, staff in action, residential bedroom, residential bathroom, residential living area, residential kitchen, architecture interior, architecture exterior, architectural detail, landscape architecture, food photography, product photography, landscape and nature, cityscape and street, vehicle, wildlife and animals, document and artwork, or abstract and other.]]

-- Fixed output contract: each text field has its own job and must not repeat the others.
Defaults.outputRules = [[OUTPUT RULES (these override any earlier instruction about output fields). Title, caption and alt text each have a different purpose; do not reuse the same sentence or wording across them.

title: the one line shown under the photo on a website, at most 90 characters, in the form "<Space or scene> - <Property>, <City>, <Country>", for example "Hotel Exterior at Dusk - Ramada by Wyndham Riyadh King Fahd Road, Riyadh, KSA" or "Meeting Room - Ramada Plaza Rize, Turkey". Title case for the space or scene. Include only the name and location parts that are confirmed; with none confirmed, give only the space or scene. No full stop.

caption: a ready-to-post caption for publishing the photo online, such as under a gallery image or in a social post. One or two natural, inviting sentences, at most 300 characters, saying what makes this frame worth looking at, and naming the property and location when confirmed. Factual: no invented amenities, claims or superlatives, no hashtags, no emoji.

alt_text: Format's "Image Description" (alt text) for screen readers and search engines. Write one concise, natural sentence that would let someone with their eyes shut picture the photo: the main subject first, then the one or two details that matter most, such as setting, light or time of day. Aim for about 80 to 150 characters; never more than 255. Name the confirmed property, and the city if there is room, only where it reads naturally. Describe only what is clearly visible — an incorrect description is worse than none. No keyword lists, no strings of commas, no promotional words, and never begin with "Image of" or "Picture of". Example: "Ramada Plaza Rize hotel tower lit up at dusk, its curved glass entrance glowing beneath a pink and violet sky."

keywords: 6 to 12 concise, flat, lower-case keywords for visible content that is NOT already in the photo's existing keywords. The first is the primary visible category.

confidence: 0 to 1, how certain you are about what the image shows.

portfolio.score: 1 to 5 as a portfolio-suitability suggestion only: 5 Hero, 4 Portfolio, 3 Supporting, 2 Needs review, 1 Reject candidate. Judge visible composition, clarity of purpose, lighting and readability, styling, distinctiveness and duplication risk. Do not claim to judge full-resolution focus, retouching or technical delivery quality.

Return JSON only, exactly this shape:
{"title":"","caption":"","alt_text":"","keywords":[""],"confidence":0.0,"portfolio":{"score":3,"label":"Supporting","recommended_use":"gallery","strengths":[""],"cautions":[""]}}]]

function Defaults.fullPrompt(guidance)
    return (guidance or Defaults.defaultPrompt) .. '\n\n' .. Defaults.outputRules
end

-- Standard prompts shipped by earlier versions. A saved prompt identical to one of these
-- was never customised, so it is upgraded to the current standard prompt.
Defaults.legacyPrompts = {
    [[You create factual, frame-specific retrieval metadata for a professional hospitality, interior and architecture photographer.

Prioritize what is visibly distinctive in THIS frame: room or scene type, architectural elements, furniture, materials, service activity, food presentation, lighting, viewpoint and composition. Do not fill the result with project-wide generic terms.

Use one primary visible category as the first keyword, choosing a concise phrase such as: hotel guest room, hotel bathroom, suite living area, hotel corridor, restaurant interior, open buffet, live cooking, bar interior, dining detail, hotel lobby, hotel lounge, meeting space, spa interior, gym interior, hotel exterior, pool area, terrace, chef at work, culinary service, staff in action, residential bedroom, residential bathroom, residential living area, residential kitchen, architecture interior, architecture exterior, architectural detail, landscape architecture, food photography, product photography, landscape and nature, cityscape and street, vehicle, wildlife and animals, document and artwork, or abstract and other.

Only use a property name, brand, city, country, official room category or client name when it is supplied explicitly in optional photographer context. Never infer it from appearance. An approved folder label is optional photographer context, not proof: use it only when it clearly matches the visible scene. Never identify or name a person, recognize a face, or infer age, ethnicity, nationality, religion, health, disability, sexual orientation, or internal emotional state. Never transcribe visible IDs, badges, documents, screens or licence plates.

Generate 6–12 concise, flat keywords. They must be specific to the image; avoid vague promotional words such as luxury, elegant, stunning, sophisticated, beautiful or modern unless they describe a named design style supplied in context.

Image title: concise factual title, no invented names.
Image caption and Image Alt Text: the same single, factual, natural-language sentence, maximum 255 characters. This text is intended for Format website Image Description / alt text. Do not keyword-stuff, market, or claim facts not visible or supplied in context.

Return JSON only, using exactly this shape:
{"title":"","keywords":[""],"description":"","confidence":0.0,"portfolio":{"score":3,"label":"Supporting","recommended_use":"gallery","strengths":[""],"cautions":[""]}}

For portfolio.score choose 1–5 as a portfolio-suitability suggestion only: 5 Hero, 4 Portfolio, 3 Supporting, 2 Needs review, 1 Reject candidate. Judge visible composition, clarity of purpose, lighting/readability, styling, distinctiveness and duplication risk. Do not claim to judge full-resolution focus, retouching or technical delivery quality.]],
}

local function comparable(text)
    return (tostring(text or ''):gsub('%s+', ' '):gsub('^ ', ''):gsub(' $', ''))
end

function Defaults.isLegacyPrompt(text)
    for _, legacy in ipairs(Defaults.legacyPrompts) do
        if comparable(text) == comparable(legacy) then return true end
    end
    return false
end

Defaults.providers = {
    { title = 'Google Gemini', value = 'gemini' },
    { title = 'OpenAI', value = 'openai' },
}

Defaults.providerInfo = {
    gemini = { name = 'Google Gemini', keyName = 'Gemini API key', keyUrl = 'https://aistudio.google.com/apikey', pricingUrl = 'https://ai.google.dev/gemini-api/docs/pricing' },
    openai = { name = 'OpenAI', keyName = 'OpenAI API key', keyUrl = 'https://platform.openai.com/api-keys', pricingUrl = 'https://platform.openai.com/docs/pricing' },
}

-- The only models offered in the interface, cheapest first. Prices are standard API
-- prices in US$ per 1M input / output tokens, checked September 2026; the provider's
-- pricing page is authoritative. `per100` is a rough estimate for 100 photos assuming
-- about 2,000 input and 1,000 output tokens per photo; thinking models can use more.
Defaults.models = {
    gemini = {
        { value = 'gemini-3.1-flash-lite', name = 'Gemini 3.1 Flash-Lite', tier = 'Economy', input = 0.25, output = 1.50 },
        { value = 'gemini-3.5-flash', name = 'Gemini 3.5 Flash', tier = 'Recommended', input = 1.50, output = 9.00 },
        { value = 'gemini-3.1-pro-preview', name = 'Gemini 3.1 Pro (preview)', tier = 'Premium', input = 2.00, output = 12.00 },
    },
    openai = {
        { value = 'gpt-5.4-nano', name = 'GPT-5.4 nano', tier = 'Economy', input = 0.20, output = 1.25 },
        { value = 'gpt-5.4-mini', name = 'GPT-5.4 mini', tier = 'Recommended', input = 0.75, output = 4.50 },
        { value = 'gpt-5.4', name = 'GPT-5.4', tier = 'Standard', input = 2.50, output = 15.00 },
        { value = 'gpt-5.5', name = 'GPT-5.5', tier = 'Premium', input = 5.00, output = 30.00 },
    },
}
Defaults.recommendedModel = { gemini = 'gemini-3.5-flash', openai = 'gpt-5.4-mini' }

function Defaults.modelInfo(provider, value)
    for _, model in ipairs(Defaults.models[provider] or {}) do
        if model.value == value then return model end
    end
end

-- Cost in US$ of one call, from the token counts the provider reports; nil for an unknown model.
function Defaults.costFor(provider, value, inputTokens, outputTokens)
    local model = Defaults.modelInfo(provider, value)
    if not model then return nil end
    return ((inputTokens or 0) * model.input + (outputTokens or 0) * model.output) / 1000000
end

function Defaults.formatCost(dollars)
    if dollars < 0.01 then return string.format('$%.4f', dollars) end
    return string.format('$%.2f', dollars)
end

function Defaults.estimatePer100(model)
    return 100 * (2000 * model.input + 1000 * model.output) / 1000000
end

-- Popup items: tier first so people choose by what they are willing to pay.
function Defaults.modelItems(provider)
    local items = {}
    for _, model in ipairs(Defaults.models[provider] or {}) do
        table.insert(items, {
            title = string.format('%s — %s  (about $%.2f per 100 photos)', model.tier, model.name, Defaults.estimatePer100(model)),
            value = model.value,
        })
    end
    return items
end

function Defaults.pricingSummary(provider)
    local lines = {}
    for _, model in ipairs(Defaults.models[provider] or {}) do
        table.insert(lines, string.format('%s — %s: $%.2f input / $%.2f output per 1M tokens, about $%.2f per 100 photos',
            model.tier, model.name, model.input, model.output, Defaults.estimatePer100(model)))
    end
    return table.concat(lines, '\n')
end

function Defaults.initialize(prefs)
    if prefs.provider ~= 'gemini' and prefs.provider ~= 'openai' then prefs.provider = 'gemini' end
    -- Earlier alphas accepted free-text model IDs; anything outside the catalogue
    -- falls back to the recommended model so the menus always show a valid choice.
    for provider, model in pairs(Defaults.recommendedModel) do
        if not Defaults.modelInfo(provider, prefs[provider .. 'Model']) then prefs[provider .. 'Model'] = model end
    end
    if prefs.temperature == nil then prefs.temperature = 0.20 end
    if prefs.batchDelayMs == nil then prefs.batchDelayMs = 700 end
    if prefs.folderHints == nil then prefs.folderHints = false end
    if prefs.learningProfile == nil then prefs.learningProfile = '' end
    if prefs.projectContext == nil then prefs.projectContext = '' end
    if prefs.sharedTags == nil then prefs.sharedTags = '' end
    if prefs.analysisPrompt == nil or prefs.analysisPrompt == '' or Defaults.isLegacyPrompt(prefs.analysisPrompt) then prefs.analysisPrompt = Defaults.defaultPrompt end
    if prefs.applyRatings == nil then prefs.applyRatings = false end
    if prefs.generatePortfolio == nil then prefs.generatePortfolio = true end
    if prefs.showAdvanced == nil then prefs.showAdvanced = false end
    if prefs.saveTitle == nil then prefs.saveTitle = true end
    if prefs.saveKeywords == nil then prefs.saveKeywords = true end
    if prefs.saveDescription == nil then prefs.saveDescription = true end
    -- 0.2 had one combined description; caption and alt text are now separate choices.
    if prefs.saveCaption == nil then prefs.saveCaption = prefs.saveDescription end
    if prefs.saveAltText == nil then prefs.saveAltText = prefs.saveDescription end
    if prefs.useExistingKeywords == nil then prefs.useExistingKeywords = true end
end

return Defaults
