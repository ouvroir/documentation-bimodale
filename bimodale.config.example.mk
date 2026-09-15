# Configuration locale — emplacement du contenu (fichiers .md + images/)
# Copier ce fichier en bimodale.config.mk et adapter le chemin.
# bimodale.config.mk est ignoré par git (chemin spécifique à la machine/au projet).
#
# Sans ce fichier, le contenu est cherché à la racine du dépôt (comportement par défaut).
#
# Syntaxe : pas d'espaces autour du "=" (fichier lu à la fois par le Makefile et par watch.sh)

SRC_DIR=/chemin/vers/mon-cours
