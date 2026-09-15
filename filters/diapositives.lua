-- Filtre Pandoc unifié :
-- 1. Collecte les images vers public/images/ et réécrit leurs chemins
-- 2. Convertit <dia-both> et <dia-only> en divs data-dia,
--    en parsant leur contenu comme Markdown+HTML (sans lignes vides obligatoires)

-- ============================================================
-- COLLECTE D'IMAGES
-- ============================================================

local output_dir = "public/images"

local image_attrs = {
  "data%-background%-image",
  "data%-src",
}

local function shell_quote(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function file_exists(path)
  local f = io.open(path, "r")
  if f then f:close() return true end
  return false
end

local function basename(path)
  return path:match("([^/]+)$") or path
end

local function expand_home(path)
  if path:sub(1, 1) == "~" then
    return (os.getenv("HOME") or "") .. path:sub(2)
  end
  return path
end

local function collect(src)
  if src == "" or src:match("^https?://") or src:match("^data:") or src:match("^//") then
    return src
  end

  src = expand_home(src)

  local resolved = src
  if not src:match("^/") then
    local input_dir = ""
    if PANDOC_STATE.input_files and PANDOC_STATE.input_files[1] then
      input_dir = PANDOC_STATE.input_files[1]:match("(.*/)") or ""
    end
    resolved = input_dir .. src
  end

  if not file_exists(resolved) then
    io.stderr:write("[diapositives] image introuvable : " .. resolved .. "\n")
    return src
  end

  os.execute("mkdir -p " .. shell_quote(output_dir))
  local filename = basename(resolved)
  os.execute("rsync -a " .. shell_quote(resolved) .. " " .. shell_quote(output_dir .. "/" .. filename))

  return "images/" .. filename
end

local function process_raw(el)
  if el.format ~= "html" then return el end
  local html = el.text

  for _, tag in ipairs({ "img", "rf%-canvas" }) do
    html = html:gsub(
      '(<' .. tag .. '%s[^>]-)src="([^"]*)"',
      function(prefix, src) return prefix .. 'src="' .. collect(src) .. '"' end
    )
  end

  for _, attr in ipairs(image_attrs) do
    html = html:gsub(
      '(' .. attr .. '=")([^"]*)"',
      function(prefix, src) return prefix .. collect(src) .. '"' end
    )
  end

  el.text = html
  return el
end

-- Appliqué sur le document principal par Pandoc avant Pandoc(doc)
function Image(el)
  el.src = collect(el.src)
  return el
end

RawBlock  = process_raw
RawInline = process_raw

-- ============================================================
-- BLOCS DIA-BOTH / DIA-ONLY
-- ============================================================

local ELEMENTS = {
  ["dia-both"] = "",
  ["dia-only"] = "seulement",
}

-- Raccourcis pour les attributs Reveal.js (évite de taper data-)
local SHORTHANDS = {
  -- État et comportement
  ["state"]                  = "data-state",
  ["visibility"]             = "data-visibility",
  ["autoslide"]              = "data-autoslide",
  ["preview-link"]           = "data-preview-link",
  ["transition-speed"]       = "data-transition-speed",
  ["notes"]                  = "data-notes",
  -- Arrière-plans
  ["bg"]                     = "data-background-color",
  ["bg-color"]               = "data-background-color",
  ["bg-gradient"]            = "data-background-gradient",
  ["bg-img"]                 = "data-background-image",
  ["bg-size"]                = "data-background-size",
  ["bg-pos"]                 = "data-background-position",
  ["bg-repeat"]              = "data-background-repeat",
  ["bg-opacity"]             = "data-background-opacity",
  ["bg-video"]               = "data-background-video",
  ["bg-video-loop"]          = "data-background-video-loop",
  ["bg-video-muted"]         = "data-background-video-muted",
  ["bg-iframe"]              = "data-background-iframe",
  ["bg-transition"]          = "data-background-transition",
  -- Auto-animate
  ["auto-animate"]           = "data-auto-animate",
  ["auto-animate-restart"]   = "data-auto-animate-restart",
  ["animate-id"]             = "data-id",
  -- Médias
  ["src"]                    = "data-src",
  ["autoplay"]               = "data-autoplay",
  ["preload"]                = "data-preload",
  -- Fragments
  ["fragment-index"]         = "data-fragment-index",
  -- Projet
  ["numbers"]                = "data-numbers",
}

local function escape(tag)
  return tag:gsub("%-", "%%-")
end

local COLOR_ATTRS = { ["data-background-color"] = true }
local IMAGE_ATTRS = { ["data-background-image"] = true, ["data-src"] = true }

local function resolve_color(v)
  if v == "" or v:match("^#") or v:match("^var%(") or v:match("%(") then return v end
  if v:match("%-") then return "var(--" .. v .. ")" end
  return v
end

-- Convertit les raccourcis d'une chaîne d'attributs HTML en attributs data- complets.
-- Gère les attributs avec valeur (key="val") et les attributs booléens (key).
-- Les attributs image sont passés par collect() pour copier les fichiers et réécrire les chemins.
local function expand_attrs(attr_str, base_attrs)
  local attrs = base_attrs or {}
  -- Attributs avec valeur
  for k, v in attr_str:gmatch('%s+([%w%-]+)="([^"]*)"') do
    local full = SHORTHANDS[k] or k
    local val = COLOR_ATTRS[full] and resolve_color(v) or v
    attrs[full] = IMAGE_ATTRS[full] and collect(val) or val
  end
  -- Attributs booléens : retirer les paires key="val" et garder les mots restants
  local remaining = attr_str:gsub('%s+[%w%-]+="[^"]*"', "")
  for k in remaining:gmatch('%s+([%w%-]+)') do
    attrs[SHORTHANDS[k] or k] = ""
  end
  return attrs
end

-- Lit le fichier source ligne par ligne et extrait les blocs dia-* dans l'ordre.
-- Le contenu interne est re-parsé comme Markdown+HTML — pas de lignes vides requises.
local function read_dia_blocks()
  local path = PANDOC_STATE.input_files and PANDOC_STATE.input_files[1]
  if not path then return {} end

  local f = io.open(path, "r")
  if not f then return {} end

  local results = {}
  local current_tag = nil
  local current_attrs = nil
  local inner = {}

  for line in f:lines() do
    if current_tag then
      if line:match("^</" .. escape(current_tag) .. ">%s*$") then
        local parsed = pandoc.read(table.concat(inner, "\n"), "markdown+raw_html")
        table.insert(results, { attrs = current_attrs, blocks = parsed.blocks })
        current_tag, current_attrs, inner = nil, nil, {}
      else
        table.insert(inner, line)
      end
    else
      for tag, value in pairs(ELEMENTS) do
        local attr_str = line:match("^<" .. escape(tag) .. "([^>]*)>%s*$")
        if attr_str then
          current_tag = tag
          current_attrs = expand_attrs(attr_str, { ["data-dia"] = value })
          break
        end
      end
    end
  end

  f:close()
  return results
end

-- Retourne le tag dia-* si le bloc contient une balise ouvrante dia-*
local function open_tag(block)
  if block.tag ~= "Para" and block.tag ~= "Plain" then return end
  for _, inline in ipairs(block.content) do
    if inline.tag == "RawInline" and inline.format == "html" then
      for tag in pairs(ELEMENTS) do
        if inline.text:match("^<" .. escape(tag) .. "[^>]*>%s*$") then
          return tag
        end
      end
    end
  end
end

-- Vrai si le bloc contient la balise fermante du tag donné
local function has_close(block, tag)
  if block.tag ~= "Para" and block.tag ~= "Plain" then return false end
  for _, inline in ipairs(block.content) do
    if inline.tag == "RawInline" and inline.format == "html" then
      if inline.text:match("^</" .. escape(tag) .. ">%s*$") then
        return true
      end
    end
  end
  return false
end

-- Applique la collecte d'images aux blocs issus de pandoc.read()
local function apply_images(blocks)
  local result = {}
  for _, block in ipairs(blocks) do
    table.insert(result, pandoc.walk_block(block, {
      Image     = function(el) el.src = collect(el.src); return el end,
      RawBlock  = process_raw,
      RawInline = process_raw,
    }))
  end
  return result
end

-- Pandoc(doc) s'exécute après Image/RawBlock/RawInline sur le document principal
function Pandoc(doc)
  local dia_blocks = read_dia_blocks()
  if #dia_blocks == 0 then return doc end

  local result = {}
  local dia_index = 0
  local i = 1
  local blocks = doc.blocks

  while i <= #blocks do
    local tag = open_tag(blocks[i])
    if tag then
      if not has_close(blocks[i], tag) then
        i = i + 1
        while i <= #blocks and not has_close(blocks[i], tag) do
          i = i + 1
        end
      end
      dia_index = dia_index + 1
      local db = dia_blocks[dia_index]
      if db then
        local processed = apply_images(db.blocks)
        table.insert(result, pandoc.Div(processed, pandoc.Attr("", {}, db.attrs)))
      end
    else
      table.insert(result, blocks[i])
    end
    i = i + 1
  end

  doc.blocks = pandoc.Blocks(result)
  return doc
end
