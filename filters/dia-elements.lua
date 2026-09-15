-- Filtre Pandoc unifié pour les web components bimodaux :
-- 1. Collecte les images vers public/images/ et réécrit leurs chemins
-- 2. Préserve <dia-both> et <dia-only> comme éléments HTML natifs
--    (dia-elements.js les instancie au runtime et gère les shorthands)
-- 3. Si prose: false, relègue le texte hors dia-both/dia-only en notes du
--    présentateur (<aside class="notes">) au lieu de le rendre visible

-- ============================================================
-- COLLECTE D'IMAGES
-- ============================================================

local output_dir = "public/images"

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
  src = src:match("^file://(.*)$") or src
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
    io.stderr:write("[dia-elements] image introuvable : " .. resolved .. "\n")
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
  for _, attr in ipairs({ "data%-background%-image", "data%-src", "data%-background%-video", "data%-background%-iframe" }) do
    html = html:gsub(
      '(' .. attr .. '=")([^"]*)"',
      function(prefix, src) return prefix .. collect(src) .. '"' end
    )
  end
  el.text = html
  return el
end

function Image(el)
  el.src = collect(el.src)
  return el
end

RawBlock  = process_raw
RawInline = process_raw

-- ============================================================
-- BLOCS DIA-BOTH / DIA-ONLY → WEB COMPONENTS
-- ============================================================

local ELEMENTS = { ["dia-both"] = true, ["dia-only"] = true }

-- Shorthands image résolus au build (les autres shorthands sont laissés au web component)
-- RawInline a déjà traité data-background-image et data-src ; seuls les raccourcis restent.
local IMAGE_SHORTHANDS = {
  { pattern = "bg%-img",    full = "data-background-image" },
  { pattern = "bg%-video",  full = "data-background-video" },
  { pattern = "bg%-iframe", full = "data-background-iframe" },
  { pattern = "src",        full = "data-src" },
}

local function escape_tag(tag)
  return tag:gsub("%-", "%%-")
end

local function resolve_image_attrs(text)
  for _, s in ipairs(IMAGE_SHORTHANDS) do
    text = text:gsub(
      '(%s)' .. s.pattern .. '="([^"]*)"',
      function(space, src)
        return space .. s.full .. '="' .. collect(src) .. '"'
      end
    )
  end
  return text
end

-- Reconstruit le texte source brut depuis une liste d'inlines.
-- On évite pandoc.write() qui échapperait \# et empêcherait de re-parser ## comme titre.
local function inlines_to_text(inlines)
  local buf = {}
  for _, il in ipairs(inlines) do
    if     il.tag == "Str"       then buf[#buf+1] = il.text
    elseif il.tag == "Space"     then buf[#buf+1] = " "
    elseif il.tag == "SoftBreak" then buf[#buf+1] = "\n"
    elseif il.tag == "LineBreak" then buf[#buf+1] = "  \n"
    elseif il.tag == "RawInline" then buf[#buf+1] = il.text
    elseif il.tag == "Code"      then buf[#buf+1] = "`" .. il.text .. "`"
    elseif il.tag == "Emph"      then buf[#buf+1] = "_" .. inlines_to_text(il.content) .. "_"
    elseif il.tag == "Strong"    then buf[#buf+1] = "**" .. inlines_to_text(il.content) .. "**"
    elseif il.tag == "Link"      then
      buf[#buf+1] = "[" .. inlines_to_text(il.content) .. "](" .. il.target .. ")"
    end
  end
  return table.concat(buf)
end

-- Re-parse une liste d'inlines comme des blocs Markdown.
-- Utilisé quand <dia-both>contenu</dia-both> tient en un seul Para (sans ligne vide).
local function reparse_inlines(inlines)
  if #inlines == 0 then return pandoc.Blocks({}) end
  return pandoc.read(inlines_to_text(inlines), "markdown+mark").blocks
end

-- Sous-liste d'inlines entre les indices from et to (inclus), encapsulée en Para.
-- Retourne nil si la tranche est vide.
local function slice_to_para(inlines, from, to)
  if from > to then return nil end
  local rest = pandoc.List()
  for j = from, to do rest:insert(inlines[j]) end
  return pandoc.Para(rest)
end

-- Détecte une balise ouvrante <dia-*> au DÉBUT d'un Para/Plain.
-- Retourne (tag, opening_html, extra_blocks_ou_nil, all_in_one_ou_nil) :
--   extra_blocks : Blocks re-parsés depuis les inlines qui suivaient la balise sur la même ligne
--                  (fermeture dans un autre bloc — ex: <dia-both>\n## Titre\n\nparagraphe)
--   all_in_one   : Blocks re-parsés (ouverture ET fermeture dans le même Para)
local function detect_open(block)
  if block.tag ~= "Plain" and block.tag ~= "Para" then return end
  local n = #block.content
  if n == 0 then return end
  local first = block.content[1]
  if first.tag ~= "RawInline" or first.format ~= "html" then return end

  for tag in pairs(ELEMENTS) do
    if first.text:match("^<" .. escape_tag(tag) .. "[^>]*>%s*$") then
      local opening = resolve_image_attrs(first.text:gsub("%s+$", ""))

      if n == 1 then
        return tag, opening   -- balise seule, cas normal
      end

      -- Inlines après la balise (on saute le SoftBreak éventuel en index 2)
      local from = (block.content[2] and block.content[2].tag == "SoftBreak") and 3 or 2
      local trailing = pandoc.List()
      for j = from, n do trailing:insert(block.content[j]) end

      -- La fermeture est-elle aussi dans ce Para ? (tout dans un seul Para, sans ligne vide)
      local last = trailing[#trailing]
      if last and last.tag == "RawInline" and last.format == "html"
         and last.text:match("^</" .. escape_tag(tag) .. "%s*>%s*$") then
        local to = (#trailing > 1 and trailing[#trailing-1].tag == "SoftBreak")
                   and #trailing-2 or #trailing-1
        local inner = pandoc.List()
        for j = 1, to do inner:insert(trailing[j]) end
        return tag, opening, nil, reparse_inlines(inner)
      end

      -- Fermeture dans un autre bloc : re-parser le trailing pour récupérer la sémantique bloc
      return tag, opening, reparse_inlines(trailing)
    end
  end
end

-- Détecte une balise fermante </dia-*> à la FIN d'un Para/Plain.
-- Retourne (trouvé, extra_ou_nil) :
--   extra : Para avec le contenu qui précédait la balise sur la même ligne.
local function detect_close(block, tag)
  if block.tag ~= "Plain" and block.tag ~= "Para" then return false end
  local n = #block.content
  if n == 0 then return false end
  local last = block.content[n]
  if last.tag ~= "RawInline" or last.format ~= "html" then return false end
  if not last.text:match("^</" .. escape_tag(tag) .. "%s*>%s*$") then return false end
  if n == 1 then return true end
  local to = (block.content[n-1] and block.content[n-1].tag == "SoftBreak") and n-2 or n-1
  return true, slice_to_para(block.content, 1, to)
end

-- Découpe les blocs du document en segments dia (tag + contenu interne)
-- et segments de texte (blocs consécutifs hors dia-both/dia-only).
local function collect_segments(blocks)
  local segments = {}
  local i = 1
  while i <= #blocks do
    local tag, opening, extra_open, all_in_one = detect_open(blocks[i])
    if tag then
      local inner = {}
      if all_in_one then
        -- Ouverture ET fermeture dans le même Para : contenu déjà re-parsé en blocs
        for _, b in ipairs(all_in_one) do table.insert(inner, b) end
      else
        if extra_open then
          for _, b in ipairs(extra_open) do table.insert(inner, b) end
        end
        i = i + 1
        while i <= #blocks do
          local closed, extra_close = detect_close(blocks[i], tag)
          if closed then
            if extra_close then table.insert(inner, extra_close) end
            break
          end
          table.insert(inner, blocks[i])
          i = i + 1
        end
      end
      table.insert(segments, { kind = "dia", tag = tag, opening = opening, inner = inner })
    else
      local last = segments[#segments]
      if last and last.kind == "text" then
        table.insert(last.blocks, blocks[i])
      else
        table.insert(segments, { kind = "text", blocks = { blocks[i] } })
      end
    end
    i = i + 1
  end
  return segments
end

function Pandoc(doc)
  local segments = collect_segments(doc.blocks)
  local result = {}

  -- prose: false → seuls les blocs dia-both/dia-only sont conservés dans le HTML ;
  -- le texte environnant (entre deux diapositives) est relégué en notes du
  -- présentateur (<aside class="notes">, repris nativement par le plugin Reveal Notes),
  -- au lieu d'être visible dans la lecture en prose. Un segment de texte sans
  -- bloc dia précédent (en tête de document) n'a pas de diapositive à
  -- rattacher : il est abandonné.
  local is_prose = doc.meta.prose ~= false
  doc.meta.prose = is_prose -- normalise la valeur par défaut pour le template ($if(prose)$)

  for idx, seg in ipairs(segments) do
    if seg.kind == "dia" then
      table.insert(result, pandoc.RawBlock('html', seg.opening))
      for _, b in ipairs(seg.inner) do table.insert(result, b) end
      if not is_prose then
        local following = segments[idx + 1]
        if following and following.kind == "text" then
          table.insert(result, pandoc.RawBlock('html', '<aside class="notes">'))
          for _, b in ipairs(following.blocks) do table.insert(result, b) end
          table.insert(result, pandoc.RawBlock('html', '</aside>'))
        end
      end
      table.insert(result, pandoc.RawBlock('html', '</' .. seg.tag .. '>'))
    elseif is_prose then
      for _, b in ipairs(seg.blocks) do table.insert(result, b) end
    end
  end

  doc.blocks = pandoc.Blocks(result)
  return doc
end
