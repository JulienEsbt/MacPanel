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
