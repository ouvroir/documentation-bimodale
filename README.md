# Documentation bimodale

Génère des pages HTML combinant prose et diapositives Reveal.js à partir de fichiers Markdown, via Pandoc.

Chaque page fonctionne en deux modes : **prose** (lecture scrollable) et **présentation** (Reveal.js plein écran), depuis une seule source.

## Structure

```
*.md                        # sources Markdown (un fichier par présentation)
index.md                    # liste des présentations pour la page d’accueil
images/                     # images source (copiées vers public/images/ au build)
pandoc.local.yaml           # config locale : bibliographie, CSL (non versionné)
pandoc.local.example.yaml   # modèle à copier pour configurer la bibliographie
bimodale.config.mk          # config locale : SRC_DIR (non versionné)
bimodale.config.example.mk  # modèle à copier pour utiliser un dossier de contenu externe
filters/
  dia-elements.lua          # filtre Pandoc : collecte images + blocs dia-*
  split-bibliography.lua    # filtre Pandoc : sépare la bibliographie (prose: false)
template/
  dia.html                  # template d’une séance (prose + diapositives)
  index.html                # template de la mosaïque des séances
  readme.html               # template de la page d’accueil par défaut (README)
serve.mjs                   # serveur de développement avec live reload
public/                     # tout ce qui est servi (kit + fichiers générés)
  assets/                   # assets statiques du kit (images de documentation…)
  fonts/                    # polices (Overused Grotesk)
  lib/                      # bibliothèques (Reveal.js 6.0.1)
  scripts/                  # JavaScript
  style/                    # feuilles de style
  *.html                    # générés par make (non versionnés)
  images/                   # généré par make images (non versionné)
```

Les assets du kit (`public/scripts/`, `public/style/`, `public/fonts/`, `public/lib/`, `public/assets/`, `public/documentation.html`) sont versionnés dans git. Les fichiers HTML et `images/` générés dans `public/` sont ignorés par `.gitignore`.

## Écriture des diapositives

### Syntaxe HTML classique

Avec l’attribut `data-dia` sur n’importe quel élément bloc :

```html
<!-- visible en prose et en présentation -->
<section data-dia="">…</section>

<!-- uniquement dans la présentation -->
<section data-dia="seulement">…</section>
```

### Web components `<dia-both>` et `<dia-only>`

Syntaxe alternative qui accepte un mélange de **Markdown, de HTML et de web components** :

```html
<!-- visible en prose et en présentation -->
<dia-both>
## Titre en Markdown

Du texte **gras**, `du code`, [des liens](#).

  <rf-canvas src="image.jpg">
    <rf-legend>Légende</rf-legend>
  </rf-canvas>
</dia-both>

<!-- uniquement dans la présentation -->
<dia-only state="centered">
## Titre centré
</dia-only>
```

Les web components acceptent des **raccourcis d’attributs** pour éviter de saisir `data-` :

#### Raccourcis d’attributs Reveal.js

| Raccourci | Attribut complet |
|---|---|
| `state` | `data-state` |
| `visibility` | `data-visibility` |
| `autoslide` | `data-autoslide` |
| `transition-speed` | `data-transition-speed` |
| `preview-link` | `data-preview-link` |
| `notes` | `data-notes` |
| **Arrière-plans** | |
| `bg` / `bg-color` | `data-background-color` |
| `bg-gradient` | `data-background-gradient` |
| `bg-img` | `data-background-image` |
| `bg-size` | `data-background-size` |
| `bg-pos` | `data-background-position` |
| `bg-repeat` | `data-background-repeat` |
| `bg-opacity` | `data-background-opacity` |
| `bg-video` | `data-background-video` |
| `bg-video-loop` | `data-background-video-loop` |
| `bg-video-muted` | `data-background-video-muted` |
| `bg-iframe` | `data-background-iframe` |
| `bg-transition` | `data-background-transition` |
| **Auto-animate** | |
| `auto-animate` | `data-auto-animate` |
| `auto-animate-restart` | `data-auto-animate-restart` |
| `animate-id` | `data-id` |
| **Médias** | |
| `src` | `data-src` |
| `autoplay` | `data-autoplay` |
| `preload` | `data-preload` |
| **Divers** | |
| `fragment-index` | `data-fragment-index` |
| `numbers` | `data-numbers` |

Les attributs booléens (sans valeur) sont supportés : `<dia-only auto-animate>`.

#### Couleurs de fond (`bg` / `bg-color`)

Les attributs `bg` et `bg-color` acceptent trois formes :

```html
<dia-only bg="#2F76E0">…</dia-only>             <!-- hex CSS -->
<dia-only bg="bleu-royal">…</dia-only>          <!-- nom court → var(--bleu-royal) -->
<dia-only bg="var(--bleu-royal)">…</dia-only>   <!-- variable CSS complète -->
```

Les noms courts (kebab-case sans `var(--)`) sont automatiquement résolus. La palette du projet :

| Famille | Base | Clair (-100) | Sombre (-500) |
|---|---|---|---|
| `bleu-royal` | `bleu-royal` | `bleu-royal-100` | `bleu-royal-500` |
| `cyber-jaune` | `cyber-jaune` | `cyber-jaune-100` | `cyber-jaune-500` |
| `ocre-rouge` | `ocre-rouge` | `ocre-rouge-100` | `ocre-rouge-500` |
| `vert-malachite` | `vert-malachite` | `vert-malachite-100` | `vert-malachite-500` |
| `vert-mante` | `vert-mante` | `vert-mante-100` | `vert-mante-500` |
| `violet-amethyste` | `violet-amethyste` | `violet-amethyste-100` | `violet-amethyste-500` |
| `gris-athenes` | `gris-athenes` | `gris-athenes-100` | `gris-athenes-500` |

Les variantes `-100` à `-900` sont toutes disponibles. L’autocomplétion VS Code les propose lors de la saisie de `bg="`.

#### États (`data-state`) disponibles

| Valeur | Effet |
|---|---|
| `centered` | Contenu centré verticalement et horizontalement |
| `intertitre` | Fond sombre, animation d’entrée décalée |
| `reframe` | Image plein cadre (avec `<rf-canvas>`) |
| `full` | Diapositive sans marge interne |
| `hide-numbers` | Masque la numérotation |

Exemples :

```html
<dia-only state="centered">
# Titre de section
</dia-only>

<dia-only state="intertitre" bg="#1a1a2e">
## Partie 2
</dia-only>

<dia-both state="reframe">
<rf-canvas src="images/photo.jpg">
<rf-legend absolute="true">Source : …</rf-legend>
</rf-canvas>
</dia-both>

<dia-only bg-img="images/paysage.jpg" bg-size="cover">
</dia-only>
```

### Outils VS Code

#### Snippets

Des snippets sont disponibles dans les fichiers `.md` et `.html`. Tapez le préfixe puis `Tab` :

| Préfixe | Résultat |
|---|---|
| `dia` | `<dia-both>` — visible en prose et en présentation |
| `dia-only` | `<dia-only>` — visible uniquement en présentation |
| `dia-title` | `<dia-only state="centered">` — titre centré |
| `dia-section` | `<dia-only state="intertitre" bg="…">` — intertitre animé |
| `dia-color` | `<dia-only bg="…">` — fond coloré (palette du projet) |
| `dia-img` | `<dia-only bg-img="…" bg-size="…">` — image de fond |
| `rf-canvas` | Cadre image reframe |
| `rf-legend` | Cadre image reframe avec légende |
| `rf-text` | Texte superposé sur une image reframe |
| `rf-mirror` | Galerie d’images reframe côte à côte |

Utilisez `Tab` pour naviguer entre les champs, `Shift+Tab` pour revenir en arrière.

#### Emmet

Emmet est activé dans les fichiers Markdown (mappé sur HTML). Les éléments personnalisés sont supportés :

```
dia-both            → <dia-both></dia-both>
dia-only            → <dia-only></dia-only>
dia-only[state=centered]>h1  → <dia-only state="centered"><h1></h1></dia-only>
rf-canvas[src=img]>rf-legend → <rf-canvas src="img"><rf-legend></rf-legend></rf-canvas>
```

> **Note** : dans les fichiers Markdown, `Tab` peut être intercepté selon le contexte (liste, indentation). Utilisez `Ctrl+Space` puis `Entrée` pour déclencher l’expansion — valable aussi bien pour Emmet que pour les snippets.

## Images

Placez vos images dans `images/` ou référencez-les par leur chemin absolu. Le filtre `filters/dia-elements.lua` les copie automatiquement vers `public/images/` au build et réécrit les chemins dans le HTML.

Chemins acceptés :

```markdown
![légende](images/photo.jpg)               ← relatif au projet
![légende](~/Photos/archive.jpg)           ← chemin absolu avec ~
![légende](/Users/moi/docs/figure.jpg)     ← chemin absolu complet
```

Attributs gérés : `src` sur `<img>` et `<rf-canvas>`, `data-background-image`, `data-src` — ainsi que leurs raccourcis `bg-img` et `src` sur les web components `<dia-both>` et `<dia-only>`.

## Options par article (frontmatter)

Ces clefs se placent dans l’en-tête YAML de chaque fichier `.md` et s’appliquent uniquement à cet article :

```yaml
---
title: Mon article
draft: false
biblio: true
prose: true
toc-depth: 3
---
```

| Clef | Défaut | Effet |
|---|---|---|
| `draft` | `false` | `true` exclut l’article de `make html` et de l’index des séances |
| `biblio` | `true` | `false` désactive citeproc pour cet article (voir [Bibliographie](#bibliographie)) |
| `prose` | `true` | `false` : seuls le titre et le conteneur de diapositives restent visibles (voir [Mode présentation](#mode-présentation)) |
| `toc-depth` | `3` | Profondeur du sommaire ; `false` ou `0` le retire |

## Bibliographie

Le projet supporte les références bibliographiques via le citeproc intégré à Pandoc, compatible avec les exports BetterBibTeX de Zotero (format `.bib`).

### Configuration

Copiez `pandoc.local.example.yaml` en `pandoc.local.yaml` et adaptez les chemins :

```yaml
citeproc: true

bibliography:
  - "/chemin/vers/Ma bibliothèque.bib"

# Style de citation (télécharger depuis https://www.zotero.org/styles)
csl: "/chemin/vers/Zotero/styles/chicago-author-date.csl"

metadata:
  reference-section-title: "Références"
```

`pandoc.local.yaml` est ignoré par git — chaque contributeur configure ses propres chemins.

### Citer dans le texte

La syntaxe de citation Pandoc est `[@clé]` ou `[@clé, p. 42]` :

```markdown
Comme le montre [@Dupont2020], ou bien [@Martin2019; @Smith2021, p. 15].
```

La clé correspond au citekey BetterBibTeX de l’entrée Zotero.

### Section Références

Citeproc insère automatiquement une section **Références** en fin de document quand des citations sont présentes. Elle n’apparaît pas dans la table des matières. Chaque entrée porte un id `ref-{clé}` pour permettre des liens directs (ex. `href="#ref-Dupont2020"`).

Pour masquer uniquement la section Références en gardant les appels de citation (ex. `(Doe 2020)`) résolus dans le texte, ajouter dans le frontmatter YAML :

```yaml
---
suppress-bibliography: true
---
```

Pour désactiver citeproc entièrement sur un article (aucun traitement des citations, appels `[@clé]` laissés tels quels), utiliser plutôt `biblio: false` — voir [Options par article](#options-par-article-frontmatter).

### Clés BibTeX invalides

Pandoc ne peut pas lire un fichier `.bib` contenant des clés avec des caractères spéciaux (`|`, `@`, `^`, `&`, `>`…). Si le build échoue avec `Error reading bibliography file`, vérifier les entrées concernées :

```sh
grep -n "^@[a-z]*{.*[|@^&>]" Ma\ bibliothèque.bib
```

Corriger dans Zotero via le champ **Extra** : `Citation Key: uneCleSansCaracteresSpeciaux`.

## Mode présentation

Ajoutez `?presentation` à l’URL pour ouvrir la page en mode plein écran.

Le lien **Présenter ↗** en haut du conteneur de diapositives ouvre directement ce mode dans un nouvel onglet.

### Notes présentateur

Le contenu prose situé **entre deux diapositives** est automatiquement capturé comme notes présentateur pour la diapositive qui le précède. Ouvrez la vue présentateur avec `S` en mode présentation.

```
<dia-only state="centered">
# Titre de la séance
</dia-only>

Ce paragraphe et les suivants apparaîtront comme notes de la diapositive précédente.
Ils restent visibles en mode prose.

<dia-both>
## Première partie
</dia-both>
```

> **Note** : en mode prose (par défaut), ce contenu doit être un frère direct de la balise `[data-dia]` dans le DOM, c’est-à-dire ne pas être imbriqué dans un `<div>` ou un autre conteneur intermédiaire — c’est toujours le cas avec la sortie Pandoc standard. En `prose: false` (voir ci-dessous), les notes sont déjà intégrées dans la diapositive au moment du build ; cette contrainte ne s’applique pas.

### Diaporama seul (`prose: false`)

Avec `prose: false` dans le frontmatter, la page HTML générée n’affiche plus que le titre et le conteneur de diapositives — aucun texte de prose, aucun sommaire, et les blocs `<dia-both>` ne s’affichent pas sous le conteneur comme ils le font par défaut.

Le texte situé entre deux diapositives n’est pas perdu : il est intégré au build comme note du présentateur pour la diapositive précédente (même mécanisme que ci-dessus, mais résolu par `filters/dia-elements.lua` plutôt qu’au runtime). Un paragraphe en tête de document, avant la première diapositive, n’a pas de diapositive à laquelle se rattacher : il est abandonné.

La bibliographie (si citeproc est actif) reste affichée en bas de page, sans les appels de citation dans le texte puisque celui-ci est masqué :

```yaml
---
prose: false
biblio: true   # optionnel, true par défaut — la biblio reste visible
---
```

## Build

```sh
make            # sync images/ + compile les .md modifiés + génère l’index
make html       # compile les .md modifiés uniquement
make index      # génère public/index.html
make images     # sync images/ → public/images/ sans rebuild HTML
make clean      # supprime les HTML générés et public/images/
```

Pour désactiver citeproc sur un build complet :

```sh
make NOCITEPROC=1 html
```

### Utiliser un dossier de contenu externe

documentation-bimodale peut servir de moteur de génération pour un contenu (fichiers `.md`, `index.md`, `images/`) situé dans un autre dossier — utile pour garder le contenu d’un cours séparé de l’outil, ou pour réutiliser le même outil pour plusieurs cours.

Copiez `bimodale.config.example.mk` en `bimodale.config.mk` et indiquez le chemin :

```make
SRC_DIR=/chemin/vers/mon-cours
```

`bimodale.config.mk` est ignoré par git — chaque projet/contributeur configure son propre chemin. Sans ce fichier, le contenu est cherché à la racine du dépôt (comportement par défaut). Le dossier `public/` (site généré) reste local à documentation-bimodale.

`SRC_DIR` peut aussi être passé ponctuellement en ligne de commande :

```sh
make SRC_DIR=/chemin/vers/mon-cours html
```

### Page d’accueil adaptive

`make index` produit `public/index.html` en deux modes selon le contenu du projet :

- **Sans présentations** (projet vierge) : compile `README.md` en page statique — consultable directement en `file://`, sans serveur.
- **Avec présentations** : compile `index.md` en prose, les séances non listées sont auto-appendées en mosaïque en bas de page.

La bascule est automatique : dès qu’un premier fichier `.md` (autre que `README.md` et `index.md`) est créé, le prochain `make index` produit la page d’index.

#### Intercaler des mosaïques dans `index.md`

Utilisez `<dia-pres>` pour placer une mosaïque de diapositives à un endroit précis dans la prose :

```html
## Séance 1 — Éthique du numérique

Introduction libre en Markdown...

<dia-pres data-presentation="02-ethique.html"></dia-pres>

## Séance 2 — Autochtonie

<dia-pres data-presentation="02-autochtonie.html" titre="Autochtonie et numérique"></dia-pres>
```

Les séances non mentionnées explicitement sont **auto-appendées en bas de page**. Ainsi :

- **Sans aucun `<dia-pres>`** dans `index.md` : toutes les séances détectées apparaissent automatiquement en mosaïque (comportement par défaut).
- **Avec des `<dia-pres>` explicites** : ceux-ci s’affichent en contexte, les séances restantes sont ajoutées à la suite.

| Attribut | Description |
|---|---|
| `data-presentation` | Chemin vers le fichier HTML de la séance (ex : `02-ethique.html`) |
| `titre` | Titre affiché dans le résumé *(optionnel — extrait du HTML sinon)* |

> **Note** : la mosaïque utilise `fetch`, elle doit être servie via `make serve`, pas ouverte en `file://`.

### Serveur de développement

Mode live avec rechargement automatique du navigateur (`Ctrl+C` pour arrêter) :

```sh
make serve
```

Démarre un serveur HTTP sur `http://localhost:8000`, surveille les sources (`.md`, `template/`, `filters/`, `images/`) et recharge le navigateur après chaque build. Requiert Node.js, Deno ou Bun (le premier disponible est utilisé) :

```sh
node serve.mjs                                              # Node.js
deno run --allow-net --allow-read --allow-run serve.mjs    # Deno
bun serve.mjs                                              # Bun
```

Mode watch seul (sans serveur ni rechargement automatique) :

```sh
chmod +x watch.sh   # la première fois
./watch.sh
```

Requiert [Pandoc](https://pandoc.org).

## Maintenance

### Mettre à jour Reveal.js

La bibliothèque est vendorisée dans `public/lib/`. La version courante est déclarée dans `package.json` pour en garder la trace.

```sh
npm install
npm update reveal.js
# repérer la nouvelle version, ex. 6.1.0
cp -r node_modules/reveal.js/dist public/lib/reveal.js-6.1.0/dist
cp -r node_modules/reveal.js/plugin public/lib/reveal.js-6.1.0/plugin
```

Puis mettre à jour les chemins dans `template/dia.html` et `template/index.html` :

```html
<!-- remplacer reveal.js-6.0.1 par reveal.js-6.1.0 -->
<link rel="stylesheet" href="lib/reveal.js-6.1.0/dist/reveal.css" />
<script src="lib/reveal.js-6.1.0/dist/reveal.js"></script>
```

L’ancien dossier `public/lib/reveal.js-6.0.1/` peut ensuite être supprimé.
