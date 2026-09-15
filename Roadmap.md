# Roadmap

## Styles et CSS

- [ ] traiter les liens dans les citations
- [ ] traiter les puces dans les citations
- [ ] styler les appels de notes dans les citations
- [ ] style des hyperliens dans les citations
- [ ] styler les légendes des illustrations
- [ ] harmoniser la couleur des citations dans les diapositives avec prose
- [ ] régler le pb de double puces lorsque numérotation (peut-être un pb avec la génération des listes de pandoc)

## Améliorations
- [ ] ajouter une ancre copiable au survol sur les titres
- [ ] améliorer l’intégration avec Reframe
- [ ] préparer une mise en page à deux colonnes
- [ ] améliorer le stylage des images
- [ ] prévoir insertion visionneuse pdf
- [ ] stylage des blocs de codes et highlight personnalisés conforme au thème

## Divers
- [ ] page d’index 
- [ ] overview reveals : styler comme la tête de page
- [ ] aide reveals : appliquer polices 
- [ ] style sombre

## Bug
- [ ] alignement dia cover


```html
<script type="application/json" class="js-hypothesis-config">
{
  "showHighlights": true,
  "groups": ["TON_ID_DE_GROUPE"]
}
</script>
<script async src="https://hypothes.is/embed.js"></script>
```

>**Limite importante à anticiper** : ce groupe doit être un groupe **privé** dont les visiteurs sont déjà membres (ou un groupe que Hypothesis expose comme accessible publiquement). l'utilisateur doit pouvoir voir ces groupes soit parce qu'il en est membre, soit parce que le document le met en avant — donc si tes lecteurs ne sont pas authentifiés dans ce groupe, ils ne pourront tout simplement pas annoter dedans, peu importe la config.