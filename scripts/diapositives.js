/** @type {Array|NodeList} */
let revealInstances;
/** @type {Object} Reveal.js instance */
let revealInstance;

document.addEventListener('DOMContentLoaded', () => {
  try {
    // 1. générer les diapositives 
    makeDiapositives();

    // 2. Instancier Reveal.js
    revealInstance = initReveal();
  } catch (e) {
    // impossible de créer le diaporama reveal.js
    console.error('Impossible de créer le diaporama reveal.js', e);
  }
});

/////////////

/**
 * Générer les diapositives à partir du balisage du document
 * @throws {Error} Erreur si l'élément conteneur `.reveal .slides` n'est pas trouvé.
 * @global document
 */
function makeDiapositives() {
  // on suppose un seul élément `.reveal` sur la page
  /** @type {HTMLElement} */
  const revealSlidesContainer = document.querySelector('.reveal .slides');
  /** @type {NodeList} */
  const diapositives = document.querySelectorAll('[data-diapositive');
  
  if (!revealSlidesContainer) {
    throw new Error('Aucun élément `.reveal` trouvé. Les diapositives n’ont pas été créées.');
  }

  diapositives.forEach(diapositive => {
    console.log({ diapositive })
    console.log(diapositive.nodeName.toLowerCase())
    if (diapositive.nodeName.toLowerCase() === 'section') {
      // transclusion directe s'il s'agit d'un élément <section>
      revealSlidesContainer.appendChild(diapositive);
    } else {
      // on recopie les attributs et le contenu du noeud dans un élément <section>
      let diapoSection = document.createElement('section');
      // copie du contenu interne
      diapoSection.innerHTML = diapositive.innerHTML;

      // copie des attributs
      // C'est une boucle simple sur la propriété `attributes`
      // Il n'y a pas de méthode pratique, comme le forEach(), qui soit disponible
      for (let i = 0; i < diapositive.attributes.length; i++) {
        diapoSection.setAttribute(
          diapositive.attributes[i].nodeName,
          diapositive.attributes[i].nodeValue
        );
      }

      // on insère la diapositive
      revealSlidesContainer.appendChild(diapoSection);
    }
  });
}

/**
 * Initialiser la présentation Reveal.js
 * @global Reveal
 * @returns {Object} Instance Reveal.js
 */
function initReveal() {
  return Reveal.initialize({
    // ratio 16:9
    width: 1200,
    height: 675,

    // espacement autour
    margin: 0.12,

    // intégré dans la page
    embedded: true,
    // activer les raccourcis-clavier uniquement si focusé
    keyboardCondition: 'focused',

    // transition style
    transition: 'none',

    // afficher les numéros (actuel / total)
    slideNumber: 'c/t',

    // ne pas animer les flèches (distraction)
    controlsTutorial: false,
    
    // visibilité égale pour flèche préc.
    controlsBackArrows: 'visible',

    // ne pas "centrer" le contenu des diapositives par défaut
    center: false,
  });
}