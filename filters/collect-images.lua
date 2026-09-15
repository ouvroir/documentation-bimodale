-- Collecte les images référencées dans le document vers public/images/
-- et réécrit leurs chemins dans le HTML généré.
-- Gère : syntaxe Markdown ![](), <img src>, data-background-image, data-src.
-- Copie uniquement si l'image source est plus récente (via rsync).

local output_dir = "public/images"

-- Attributs HTML dont la valeur est un chemin d'image (hors <img src>)
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
    io.stderr:write("[collect-images] introuvable : " .. resolved .. "\n")
    return src
  end

  os.execute("mkdir -p " .. shell_quote(output_dir))

  local filename = basename(resolved)
  os.execute("rsync -a " .. shell_quote(resolved) .. " " .. shell_quote(output_dir .. "/" .. filename))

  return "images/" .. filename
end

-- Syntaxe Markdown : ![alt](chemin)
function Image(el)
  el.src = collect(el.src)
  return el
end

-- Blocs HTML bruts : <img src="...">, data-background-image="...", data-src="..."
local function process_raw(el)
  if el.format ~= "html" then return el end
  local html = el.text

  -- <img src="...">, <rf-canvas src="...">
  for _, tag in ipairs({ "img", "rf%-canvas" }) do
    html = html:gsub(
      '(<' .. tag .. '%s[^>]-)src="([^"]*)"',
      function(prefix, src) return prefix .. 'src="' .. collect(src) .. '"' end
    )
  end

  -- Autres attributs image (data-background-image, data-src…)
  for _, attr in ipairs(image_attrs) do
    html = html:gsub(
      '(' .. attr .. '=")([^"]*)"',
      function(prefix, src) return prefix .. collect(src) .. '"' end
    )
  end

  el.text = html
  return el
end

RawBlock  = process_raw
RawInline = process_raw
