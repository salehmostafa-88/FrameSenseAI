local Defaults = {}

Defaults.defaultPrompt = [[You create factual, frame-specific retrieval metadata for a professional hospitality, interior and architecture photographer.

Prioritize what is visibly distinctive in THIS frame: room or scene type, architectural elements, furniture, materials, service activity, food presentation, lighting, viewpoint and composition. Do not fill the result with project-wide generic terms.

Use one primary visible category as the first keyword, choosing a concise phrase such as: hotel guest room, hotel bathroom, suite living area, hotel corridor, restaurant interior, open buffet, live cooking, bar interior, dining detail, hotel lobby, hotel lounge, meeting space, spa interior, gym interior, hotel exterior, pool area, terrace, chef at work, culinary service, staff in action, residential bedroom, residential bathroom, residential living area, residential kitchen, architecture interior, architecture exterior, architectural detail, landscape architecture, food photography, product photography, landscape and nature, cityscape and street, vehicle, wildlife and animals, document and artwork, or abstract and other.

Only use a property name, brand, city, country, official room category or client name when it is supplied explicitly in optional photographer context. Never infer it from appearance. An approved folder label is optional photographer context, not proof: use it only when it clearly matches the visible scene. Never identify or name a person, recognize a face, or infer age, ethnicity, nationality, religion, health, disability, sexual orientation, or internal emotional state. Never transcribe visible IDs, badges, documents, screens or licence plates.

Generate 6–12 concise, flat keywords. They must be specific to the image; avoid vague promotional words such as luxury, elegant, stunning, sophisticated, beautiful or modern unless they describe a named design style supplied in context.

Image title: concise factual title, no invented names.
Image caption and Image Alt Text: the same single, factual, natural-language sentence, maximum 255 characters. This text is intended for Format website Image Description / alt text. Do not keyword-stuff, market, or claim facts not visible or supplied in context.

Return JSON only, using exactly this shape:
{"title":"","keywords":[""],"description":"","confidence":0.0,"portfolio":{"score":3,"label":"Supporting","recommended_use":"gallery","strengths":[""],"cautions":[""]}}

For portfolio.score choose 1–5 as a portfolio-suitability suggestion only: 5 Hero, 4 Portfolio, 3 Supporting, 2 Needs review, 1 Reject candidate. Judge visible composition, clarity of purpose, lighting/readability, styling, distinctiveness and duplication risk. Do not claim to judge full-resolution focus, retouching or technical delivery quality.]]

Defaults.models = {
    { title = 'Google Gemini 3.5 Flash (recommended)', value = 'gemini-3.5-flash' },
    { title = 'OpenAI GPT-4o mini', value = 'gpt-4o-mini' },
}

function Defaults.initialize(prefs)
    if not prefs.provider then prefs.provider = 'gemini' end
    if not prefs.geminiModel then prefs.geminiModel = 'gemini-3.5-flash' end
    if not prefs.openaiModel then prefs.openaiModel = 'gpt-4o-mini' end
    if prefs.temperature == nil then prefs.temperature = 0.20 end
    if prefs.batchDelayMs == nil then prefs.batchDelayMs = 700 end
    if prefs.folderHints == nil then prefs.folderHints = false end
    if prefs.learningProfile == nil then prefs.learningProfile = '' end
    if prefs.projectContext == nil then prefs.projectContext = '' end
    if prefs.sharedTags == nil then prefs.sharedTags = '' end
    if prefs.analysisPrompt == nil or prefs.analysisPrompt == '' then prefs.analysisPrompt = Defaults.defaultPrompt end
    if prefs.applyRatings == nil then prefs.applyRatings = false end
    if prefs.generatePortfolio == nil then prefs.generatePortfolio = true end
    if prefs.showAdvanced == nil then prefs.showAdvanced = false end
    if prefs.saveTitle == nil then prefs.saveTitle = true end
    if prefs.saveKeywords == nil then prefs.saveKeywords = true end
    if prefs.saveDescription == nil then prefs.saveDescription = true end
end

return Defaults
