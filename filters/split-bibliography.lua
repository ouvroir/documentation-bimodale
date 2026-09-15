-- S'exécute après citeproc (donc après filters/dia-elements.lua dans la
-- commande pandoc). Quand prose: false, sépare la bibliographie générée par
-- citeproc (<h1 id="bibliography"> + <div id="refs">) du reste du corps,
-- pour que le template puisse la garder visible pendant que $body$
-- (diapositives + notes) est masqué.
--
-- citeproc insère ces deux blocs juste avant les RawBlock de fin de document
-- (nos balises fermantes </aside>/</dia-both>) plutôt qu'à la toute fin :
-- on ne peut donc pas couper "à partir du premier bloc bibliographie", il
-- faut extraire précisément ces deux identifiants, où qu'ils se trouvent.
local BIBLIOGRAPHY_IDS = { bibliography = true, refs = true }

function Pandoc(doc)
  if doc.meta.prose ~= false then return doc end

  local body = {}
  local biblio = {}

  for _, block in ipairs(doc.blocks) do
    if BIBLIOGRAPHY_IDS[block.identifier] then
      table.insert(biblio, block)
    else
      table.insert(body, block)
    end
  end

  doc.blocks = pandoc.Blocks(body)
  doc.meta.biblio = pandoc.MetaBlocks(biblio)
  return doc
end
