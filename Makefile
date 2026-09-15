# Lit une clef booléenne de l'en-tête YAML d'un fichier .md (valeur par défaut si absente)
# Usage : $(call frontmatter,fichier,clef,valeur_par_defaut)
frontmatter = $(shell awk -v key="$(2)" -v default="$(3)" '/^---[ \t]*$$/{c++;next} c==1 && $$0 ~ "^"key":[ \t]*"{val=$$0; sub("^"key":[ \t]*","",val); sub("[ \t]*$$","",val); print val; found=1; exit} c==2{exit} END{if(!found) print default}' $(1))

# Config locale optionnelle : emplacement du contenu (.md + images/), pour
# utiliser documentation-bimodale comme moteur externe à un dossier de cours.
# Copier bimodale.config.example.mk → bimodale.config.mk et adapter SRC_DIR.
-include bimodale.config.mk
SRC_DIR        ?= .
# Make traite les espaces comme des séparateurs (wildcard, patsubst, prérequis) :
# un SRC_DIR avec espace casse silencieusement la détection des sources.
ifneq ($(words $(SRC_DIR)),1)
  $(error SRC_DIR ne doit pas contenir d'espace : "$(SRC_DIR)")
endif

SOURCES        := $(filter-out $(SRC_DIR)/README.md $(SRC_DIR)/index.md,$(wildcard $(SRC_DIR)/*.md))
# Exclut les articles marqués `draft: true`
SOURCES        := $(foreach f,$(SOURCES),$(if $(filter true,$(call frontmatter,$(f),draft,false)),,$(f)))
TARGETS        := $(patsubst $(SRC_DIR)/%.md,public/%.html,$(SOURCES))
TEMPLATE       := template/dia.html
INDEX_TEMPLATE := template/index.html
README_TEMPLATE := template/readme.html
FILTER         := filters/dia-elements.lua
FILTER_POST    := filters/split-bibliography.lua
INDEX_META     := .seances-meta.yaml

# Config locale optionnelle (bibliographie, CSL, citeproc)
# Copier pandoc.local.example.yaml → pandoc.local.yaml et adapter les chemins
# Pour désactiver : make NOCITEPROC=1 html
PANDOC_LOCAL   := $(wildcard pandoc.local.yaml)
NOCITEPROC     ?= 0
ifeq ($(NOCITEPROC),1)
  PANDOC_LOCAL_FLAGS :=
else
  PANDOC_LOCAL_FLAGS := $(if $(PANDOC_LOCAL),--defaults=$(PANDOC_LOCAL),)
endif

.PHONY: all html index images clean serve help

# Cible par défaut
.DEFAULT_GOAL := help

all: images html index

# Génère les HTML modifiés depuis les .md
html: $(TARGETS)

public/%.html: TOC_DEPTH = $(call frontmatter,$<,toc-depth,3)
public/%.html: BIBLIO = $(call frontmatter,$<,biblio,true)
public/%.html: $(SRC_DIR)/%.md $(TEMPLATE) $(FILTER) $(FILTER_POST)
	pandoc $< -f markdown+mark -t html --template=$(TEMPLATE) --lua-filter=$(FILTER) --no-highlight $(if $(filter false 0,$(TOC_DEPTH)),,--toc --toc-depth=$(TOC_DEPTH)) $(if $(filter false,$(BIBLIO)),,$(PANDOC_LOCAL_FLAGS)) --lua-filter=$(FILTER_POST) -o $@
	@echo "→ $@"

# Auto-génère les métadonnées des séances depuis les sources (triées par nom)
$(INDEX_META): $(SOURCES)
	@printf 'seances:\n' > $@
	@for f in $(sort $(SOURCES)); do \
		html=$$(basename "$$f" .md).html; \
		titre=$$(basename "$$f" .md); \
		printf '  - titre: "%s"\n    fichier: %s\n' "$$titre" "$$html" >> $@; \
	done
	@echo "→ $(INDEX_META)"

# Génère la page d'index : README (sans séances) ou mosaïque (avec séances)
index: public/index.html

ifneq ($(SOURCES),)
public/index.html: $(SRC_DIR)/index.md $(INDEX_TEMPLATE) $(INDEX_META)
	pandoc $< -f markdown -t html --template=$(INDEX_TEMPLATE) --metadata-file=$(INDEX_META) -o $@
	@echo "→ $@ (mosaïque)"
else
public/index.html: $(if $(wildcard $(SRC_DIR)/README.md),$(SRC_DIR)/README.md,README.md) $(README_TEMPLATE)
	pandoc $< -f gfm -t html --template=$(README_TEMPLATE) -o $@
	@echo "→ $@ (documentation)"
endif

# Synchronise images/ → public/images/ sans rebuild HTML
images:
	@mkdir -p public/images
	@rsync -a $(SRC_DIR)/images/ public/images/
	@echo "→ public/images/"

serve:
	@{ command -v node >/dev/null 2>&1 && exec env SRC_DIR=$(SRC_DIR) node serve.mjs; } || \
	 { command -v deno >/dev/null 2>&1 && exec env SRC_DIR=$(SRC_DIR) deno run --allow-net --allow-read --allow-run --allow-env=SRC_DIR serve.mjs; } || \
	 { command -v bun  >/dev/null 2>&1 && exec env SRC_DIR=$(SRC_DIR) bun serve.mjs; } || \
	 { echo "Erreur : Node, Deno ou Bun requis" >&2; exit 1; }

clean:
	rm -f $(TARGETS) public/index.html $(INDEX_META)
	rm -rf public/images

help:
	@echo "Cibles disponibles :"
	@echo "  all      compile les présentations modifiées, synchronise les images et génère l’index"
	@echo "  html     compile les présentations .md modifiées vers public/"
	@echo "  index    génère public/index.html (README si aucune présentation, mosaïque sinon)"
	@echo "  images   synchronise images/ → public/images/ sans rebuild HTML"
	@echo "  serve    démarre le serveur de développement sur http://localhost:8000"
	@echo "  clean    supprime les HTML générés et public/images/"
	@echo "  help     affiche cette aide"
	@echo ""
	@echo "Options :"
	@echo "  NOCITEPROC=1  désactive citeproc (make NOCITEPROC=1 html)"
	@echo "  SRC_DIR=...   dossier des sources .md + images/ (défaut : .) — voir bimodale.config.example.mk"
	@echo ""
	@echo "Clefs d'en-tête YAML (par article) :"
	@echo "  draft: true         exclut l'article de la compilation et de l'index"
	@echo "  biblio: false       désactive citeproc pour cet article"
	@echo "  prose: false        ne sort que les blocs dia-both/dia-only"
	@echo "  toc-depth: 3        profondeur du sommaire (défaut 3) ; false ou 0 le retire"
