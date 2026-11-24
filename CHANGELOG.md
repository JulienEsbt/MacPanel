# Changelog

## 0.4.2 — 2026-11-24

- Commandes de luminosité placées avant les options de liaison et de clavier.
- Écart fixe ajusté explicitement par −/+, à un point près, sans petit curseur voisin de la luminosité.
- Ligne de volume masquée si l’écran ne confirme pas le support DDC/CI ; commande conservée pour les écrans compatibles.

## 0.4.1 — 2026-11-24

- Curseurs de luminosité liés dans les deux sens, sans modifier implicitement l’écart fixe ; bornes ajustées pour éviter les zones sans effet.
- Distinction explicite entre absence de réponse DDC/CI pour le son et commande disponible.

## 0.4.0 — 2026-11-24

- Panneau personnalisable : ordre et visibilité des rubriques et commandes conservés.
- Top des applications par CPU ou mémoire résidente, enfants accessibles inclus ; mesure limitée au panneau Système visible.
- Synchronisation optionnelle de luminosité depuis l’écran intégré, décalages persistants par écran ; suspension en veille/verrouillage.
- Volume DDC/CI des haut-parleurs des écrans compatibles, sans modifier la sortie audio du Mac.
- Éjection groupée confirmée des volumes externes éjectables, erreurs conservées sans démontage forcé.


## 0.3.1 — 2026-11-24

- Follow native brightness changes while the menu panel is open; stop observation
  when it closes without cancelling display discovery used by background shortcuts.
- Ignore stale brightness reads when a new slider or shortcut write starts.
- Shorten shortcut instructions and move secondary explanations into the tooltip.

## 0.3.0 — 2026-11-24

### Added
- Optional Control + Option + Up/Down shortcuts for all adjustable external displays,
  including when the menu panel is closed. Native brightness keys remain under macOS control.
- Bounded 1/16 steps and a 20% floor for software dimming.
- Saved shortcut preference and conflict status; cleanup on lock, sleep and quit,
  with resumption after unlock/wake.
- Tests for brightness bounds, invalid input and feature-specific shortcut routing.

### Fixed
- Route registered hot-key events by signature so brightness commands cannot open
  the menu panel or interfere with its own shortcut.

### Security
- Dedicated shortcuts avoid keyboard event taps and additional privacy permissions.

## 0.2.1 — 2026-11-23

- Display used storage against total capacity, with free space on a separate line.
- Use filesystem free space consistently, so used and free values add up to total
  capacity; purgeable data remains included in used space.

## 0.2.0 — 2026-11-23

### Added
- Separate System, Displays and Disks views.
- Memory pressure and local Wi-Fi/Ethernet transfer rates.
- Mounted-volume capacity, Finder access and guarded external-volume ejection.
- Per-display brightness: Apple hardware control, Apple Silicon DDC/CI, and software dimming when hardware control is unavailable.
- Brightness changes while dragging, with coalesced hardware requests.
- Configurable global shortcut, including correct letter mapping for AZERTY keyboards.
- English/French documentation and screenshots.

### Fixed
- Off-screen menu panel placement in a multi-display setup with different vertical origins.

## 0.1.0 — 2026-11-23

- Initial local application: CPU/RAM/GPU readings, five quick controls, temporary awake sessions and launch-at-login registration.
- Native AppKit lifecycle and SwiftUI panel, without a privileged helper.
