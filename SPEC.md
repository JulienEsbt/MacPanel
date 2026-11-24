# MacPanel 0.1

Application macOS native indépendante, locale, sans publicité, réseau, compte,
IA, dépendance externe ou service administrateur. Périmètre demandé le 23/11/2026.

## Capacités et ordre

| Module | Responsabilité | Dépendance |
|---|---|---|
| metrics | CPU global, RAM hors cache, GPU du pilote ; indisponibilité explicite | — |
| controls | État réel et commandes rapides, erreurs visibles | — |
| awake | Assertion temporaire Mac/écran, libérée à échéance/verrouillage/quitter | — |
| panel | Panneau natif, clavier, clair/sombre, ouverture à la connexion | metrics, controls, awake |

Ordre : calculs et tests → mesures réelles → commandes → panneau → validation.
L'utilisateur a confirmé l'app indépendante et le périmètre de la V1.

## Critères

- Une icône de barre des menus ; aucune fenêtre spontanée à la connexion.
- Un panneau compact, valeurs accessibles et commandes nommées.
- CPU par différence de compteurs, RAM unifiée estimée hors cache fichiers,
  GPU seulement si le pilote publie une valeur valide entre 0 et 100.
- Aucun échantillonnage matériel lorsque le panneau est fermé.
- Lire l'état système à l'ouverture et après une action ; ne pas afficher un
  succès lorsque la commande échoue. Aucune commande shell construite avec du texte utilisateur.
- Mode sombre, icônes du bureau, Dock et barre des menus automatiques, muet.
- Maintien éveillé 15/30/60 minutes, arrêt manuel et automatique ; aucune
  modification persistante de l'économiseur ou de la protection par mot de passe.
- Un refus d'automatisation du mode sombre affiche une explication, sans boucler.
- Contrôle des écrans exclu de la V1, MonitorControl et OpenDente inchangés.

## Construction et vérification

`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodegen generate`

`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme MacPanel -destination 'platform=macOS' -derivedDataPath .build test`

Tests XCTest locaux des calculs et des valeurs indisponibles ; validation des
vraies commandes dans l'interface avec restauration des réglages, contrôle des
assertions de veille et mesure d'activité lorsque le panneau est fermé.
Sources dans `Sources/`, tests dans `Tests/`. Swift 6, types courts et fonctions
pures pour les calculs ; APIs Apple natives pour les opérations système.

## Limites

Les préférences Finder/Dock et compteurs GPU ne sont pas des contrats stables
entre versions macOS. Échec explicite si indisponibles ; ne jamais demander root.
Le mode sombre nécessite une autorisation d'automatisation locale.
Les opérations bureau/Dock peuvent relancer Finder ou Dock, expliqué dans l'aide.
Pas de publication ou de push sans demande explicite.

## Extension 0.2 demandée le 23/11/2026

- Système : pression mémoire du système, débits entrants/sortants des interfaces
  physiques actives, sans requête réseau ; première mesure indisponible avant deux relevés.
- Disques : volumes visibles, capacité et espace disponible, ouverture Finder,
  éjection uniquement pour volumes externes éjectables ; erreur conservée si occupé.
- Écrans : luminosité par écran, lecture réelle et retour d'erreur. Les interfaces
  Apple privées et DDC sont isolées, sans service root, avec détection des capacités.
  MonitorControl reste installé jusqu'à validation du remplacement sur le matériel réel.
- Raccourci global configurable parmi quelques combinaisons, option désactivée,
  conflit signalé et réglage conservé. Pas de permission de lecture des frappes.
- Trois vues compactes. Les lectures périodiques cessent panneau fermé ; seules
  les notifications système et le raccourci enregistré restent en attente.
- Aucun ajout audio, profil, suivi batterie ou fonction en doublon d'OpenDente.


## 0.3 — raccourcis de luminosité externes

- Option persistante et désactivable dans Écrans, sans nouvelle dépendance.
- Contrôle + Option + ↑/↓ agit sur tous les écrans externes réglables par pas de 1/16 ;
  minimum logiciel de 20 %. Les touches de luminosité natives restent inchangées.
- Sans écran externe réglable, ne modifier aucun écran intégré.
- Enregistrement Carbon de deux raccourcis précis ; conflit signalé, aucun événement
  de saisie ordinaire écouté et aucune permission supplémentaire requise.
- Routage par signature distincte du raccourci d’ouverture du panneau.
- Écritures matérielles asynchrones et coalescées. Fonctionnement panneau fermé,
  découverte événementielle des écrans, arrêt au verrouillage/veille/quitter.
- Le propriétaire a choisi ce raccourci dédié afin d’éviter la permission très large
  que macOS 27.3 présente pour l’interception des touches de luminosité natives.
- MonitorControl retiré à la demande du propriétaire ; réglages conservés pour retour.

## 0.4 — extensions quotidiennes (24/11/2026)

| Module | Contrat | Vérification |
|---|---|---|
| panel-layout | Rubriques et commandes masquées/réordonnées, conservées localement ; réglages toujours accessibles | préférences isolées et relance |
| app-usage | CPU par différence de compteurs, RAM résidente des apps et enfants accessibles de l’utilisateur ; panneau Système seulement | agrégation, PID réutilisé, arrêt de collecte |
| display-sync | Option explicite, écran intégré source, décalage ±50 points par UUID ; lecture source 1/s même panneau fermé, suspension verrouillage/veille | bornes, reprise, écran réel |
| display-audio | VCP DDC 0x62 seulement si confirmé, curseur en direct et écritures coalescées ; pas de changement de sortie audio | protocole et refus, matériel compatible |
| disk-eject-all | Confirmation, identité revalidée avant chaque volume ; refuser internes/inconnus, rapport partiel sans forcer | volumes occupés et disparition |

Ordre : préférences/mesures → éjection → écrans → interface → suites natives et build signé.
Pas de mode présentation, pas de lanceur de scripts/Raccourcis ajouté. Aucun accès sensible nouveau.

### Correction 0.4.1
La liaison est bidirectionnelle dans le panneau ; les touches du Mac restent la source de suivi en arrière-plan. L’écart se règle explicitement et reste fixe. Le curseur externe est borné à la plage atteignable avec cet écart. Un écran sans réponse DDC valide pour le son n’affiche pas de faux curseur audio.

### Finitions 0.4.2
Les commandes par écran précèdent les options de liaison et de raccourcis. L’écart fixe se modifie explicitement par pas de 1 point avec −/+, entre −50 et +50, sans recalcul depuis les niveaux mesurés. La saturation d’un écran peut réduire l’écart effectivement visible. L’absence de capacité audio DDC ne crée plus de ligne audio dans le panneau.
