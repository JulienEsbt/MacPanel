<p align="center"><img src="docs/images/macpanel-mark.svg" width="80" alt="Icône MacPanel"></p>
<h1 align="center">MacPanel</h1>
<p align="center"><strong>L’essentiel de votre Mac, à portée de menu.</strong><br>Commandes rapides, activité système, luminosité et stockage dans un petit panneau natif.</p>
<p align="center">
  <a href="https://github.com/JulienEsbt/MacPanel/actions/workflows/macos.yml"><img src="https://github.com/JulienEsbt/MacPanel/actions/workflows/macos.yml/badge.svg" alt="Compilation et tests macOS"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-333333?logo=apple" alt="macOS 14 minimum">
  <img src="https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white" alt="Swift 6">
  <a href="LICENSE"><img src="https://img.shields.io/badge/licence-MIT-blue" alt="Licence MIT"></a>
</p>
<p align="center"><a href="README.md">English</a> · <strong>Français</strong></p>

MacPanel rassemble les commandes et les mesures utiles du Mac dans une seule application de barre des menus.
Développée avec **SwiftUI et AppKit**, elle fonctionne localement, sans compte, publicité, analyse d’usage,
fonction d’IA ou service administrateur. Les mesures matérielles s’arrêtent à la fermeture du panneau.

**Version publique initiale · 0.2.1.** L’interface est actuellement en français ; la documentation existe en français et en anglais.

## Aperçu

<table>
  <tr><th>Système</th><th>Écrans</th><th>Disques</th></tr>
  <tr>
    <td><img src="docs/images/system-dark.png" width="270" alt="CPU, RAM, GPU, pression mémoire, débits réseau et commandes rapides"></td>
    <td><img src="docs/images/displays-dark.png" width="270" alt="Curseurs indépendants pour les écrans intégré et externe"></td>
    <td><img src="docs/images/disks-dark.png" width="270" alt="Espace disponible et accès au volume dans Finder"></td>
  </tr>
</table>

Captures réelles de MacPanel sur un MacBook Air M3. Les capacités des écrans et les mesures de stockage dépendent du matériel.

## Fonctionnalités

| Domaine | Ce que propose MacPanel |
|---|---|
| **Activité système** | Utilisation globale CPU/GPU, estimation de la mémoire unifiée utilisée et pression mémoire de macOS. |
| **Réseau** | Débits entrants et sortants Wi-Fi/Ethernet issus des compteurs locaux. Aucun serveur de test ni inspection des paquets. |
| **Commandes rapides** | Mode sombre, icônes du bureau, masquage automatique du Dock/de la barre des menus, et Muet sur les sorties compatibles. |
| **Maintien éveillé** | Sessions de 15, 30 ou 60 minutes ; arrêt manuel, à échéance, au verrouillage, à la veille ou en quittant. |
| **Écrans** | Luminosité par écran, modifiée pendant le déplacement du curseur. Commandes matérielles Apple/DDC compatibles et atténuation logicielle explicitement indiquée en repli. |
| **Stockage** | Volumes montés, espace utilisé sur le total et espace libre, ouverture dans Finder et éjection des volumes externes compatibles. |
| **Accès quotidien** | Raccourci configurable, **Contrôle + Option + M** par défaut, et ouverture à la connexion sans afficher le panneau. |

## Utilisation

Lancez MacPanel depuis Applications, puis cliquez sur l’icône des **trois curseurs** dans la barre des menus ou utilisez **⌃⌥M**.
Les vues **Système**, **Écrans** et **Disques** regroupent les fonctions. Le raccourci peut être changé ou désactivé dans Système.

Le premier changement d’apparence peut demander l’autorisation de piloter **Événements système**.
Ces fonctions ne demandent ni Accessibilité, ni Enregistrement de l’écran, ni Accès complet au disque.
Les commandes bureau/Dock/barre peuvent relancer leur composant macOS ; les fichiers restent en place.

## Compiler le projet

Prérequis : **macOS 14+**, **Xcode 16+** avec Swift 6 et [XcodeGen](https://github.com/yonaskolb/XcodeGen).
Aucune dépendance Swift Package à télécharger.

```sh
git clone https://github.com/JulienEsbt/MacPanel.git
cd MacPanel
brew install xcodegen
bash scripts/test.sh
bash scripts/build.sh
```

L’application est produite dans `.build/Build/Products/Release/MacPanel.app`.
Quittez une ancienne copie avant de la remplacer dans Applications.

La compilation utilise par défaut une signature locale ad hoc. Une identité Apple existante peut être choisie :

```sh
MACPANEL_SIGN_IDENTITY="Votre identité de signature existante" \
MACPANEL_TEAM="Votre identifiant d’équipe" bash scripts/build.sh
```

Le script ne crée aucun certificat et ne change pas le Xcode sélectionné globalement.
Il n’existe actuellement **aucun téléchargement précompilé notarié**. La signature de développement local n’est pas une notarisation.

## Choix et limites

- **Activité réduite en arrière-plan :** mesures CPU/GPU/mémoire/réseau toutes les deux secondes lorsque le panneau est ouvert ; lecture des disques toutes les cinq secondes lorsqu’elle est active. Aucun historique conservé.
- **Mesures explicites :** une valeur absente affiche `—`. La mémoire utilisée est estimée ; la pression mémoire correspond au niveau du système, pas à un seuil déduit du pourcentage occupé. Le compteur GPU dépend du pilote.
- **Compatibilité des écrans :** la luminosité Apple et le transport DDC Apple Silicon utilisent des interfaces Apple privées détectées dynamiquement. Elles peuvent changer selon macOS. Le contrôle matériel dépend de l’écran, de la connexion et de l’activation de DDC/CI. Le DDC externe est actuellement implémenté pour Apple Silicon.
- **Atténuation logicielle :** elle modifie les tables de rendu de l’image, sans réduire le rétroéclairage ou la consommation de l’écran. Elle est temporaire et restaurée en quittant si MacPanel possède encore le réglage appliqué. D’autres utilitaires d’écran peuvent interagir avec elle.
- **Stockage :** espace utilisé et espace libre proviennent des mêmes compteurs du système de fichiers. L’espace utilisé inclut les données que macOS peut récupérer. Des volumes APFS peuvent partager leur capacité ; elle ne s’additionne pas. macOS conserve le contrôle de l’éjection des volumes occupés. Aucun nettoyage de fichiers ni démontage forcé.
- **Veille :** l’app ne continue pas à exécuter du code quand le Mac dort ou est éteint. Le maintien éveillé ne remplace pas la veille manuelle ou la fermeture du capot.
- **Rôles séparés :** la gestion de charge reste dans [OpenDente](https://github.com/JulienEsbt/OpenDente). MacPanel ne duplique pas ses limites et commandes de batterie.

## Développement

- [Spécification](SPEC.md) — périmètre et comportement
- [Validation](VALIDATION.md) — matériel testé, vérifications et limites
- [Changelog](CHANGELOG.md) — évolutions
- [Contribution](CONTRIBUTING.md) — compilation, tests et règles de modification
- [Sécurité](SECURITY.md) — signaler un problème de sécurité

Les tests XCTest couvrent les calculs, les mesures absentes/invalides, les protections d’éjection,
les réponses DDC, la disposition du clavier, le placement multi-écrans et les assertions temporaires de veille.
La compatibilité matérielle doit toujours être vérifiée avec l’écran, le câble et le dock concernés.

## Crédits et licence

Projet créé par [Julien Esterbet](https://github.com/JulienEsbt), sous [licence MIT](LICENSE).

Le transport des écrans externes adapte des parties de [waydabber/m1ddc](https://github.com/waydabber/m1ddc),
également sous MIT. Ses mentions de copyright et sa licence sont conservées dans le dépôt et dans l’app.
Les [mentions tierces](THIRD_PARTY.md) détaillent la révision et le périmètre repris.
[MonitorControl](https://github.com/MonitorControl/MonitorControl) et [Stats](https://github.com/exelban/stats)
servent de références de produit ; MacPanel est un projet indépendant.
