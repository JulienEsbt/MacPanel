# Local validation

## 0.3.1 — 24 November 2026

- 34 native XCTest tests passed, including an externally changed brightness reading
  and stopping observation when the panel is closed, using a controlled reader.
- Signed Release build installed in `/Applications/MacPanel.app`.
- The owner confirmed the built-in display slider and percentage follow native
  brightness keys in under one second with the panel left open.
- Native display readings run at approximately 350 ms intervals while the panel is
  open, subject to hardware latency. No ordinary key events are observed or recorded.
- The shortcut caption is now one short line, with secondary details in its tooltip.
- External-screen shortcut hardware validation remains deferred until a screen is attached.

## 0.3.0 — 24 November 2026

- 33 native XCTest tests passed, including bounded brightness changes, rejection
  of invalid input and routing by registered shortcut identifier/signature. A real
  Carbon event dispatch also verifies that brightness commands do not open the panel.
- Signed Release build succeeded and replaced 0.2.1 in `/Applications/MacPanel.app`.
- Owner selected dedicated Control + Option + Up/Down shortcuts instead of native
  media-key interception. No new broad privacy permission was granted; the authorization
  dialog was cancelled and the event-tap implementation removed.
- Runtime UI shows the external-brightness switch enabled and shortcuts active, with
  an explicit “no adjustable external screen” message. Sending Control + Option +
  Up/Down through the UI left the built-in slider at 37.5% and the panel unchanged.
- No external display is currently attached: physical external brightness effects
  remain unverified and must not be presented as a completed hardware test.
- MonitorControl was stopped and moved to Trash at the owner's explicit request;
  its Homebrew cask registration was removed. Preferences were preserved for rollback.
- GitHub CI for the previous 0.2.1 commit completed successfully.
- Existing repository screenshots remain unchanged, as requested.

## 0.2.1 — 23 November 2026

- 28 native XCTest tests passed locally, including missing/invalid storage counters
  and consistency between used, free and total capacity.
- Disk usage now uses the filesystem free-space counter. The important-usage API,
  which includes purgeable data, is no longer used to infer occupied storage.
- Release build succeeded. GitHub screenshots intentionally remain unchanged for a
  later visual update requested by the owner.

## 0.2.0 — 23 November 2026

**Environment:** MacBook Air M3, 16 GB; macOS 27.3 beta (26C5047e), Xcode 27.2 (27B52).
Local success on this setup does not establish compatibility with every supported macOS version or monitor.

### Automated checks

- **27 XCTest tests passed**, zero failures, in the final local run.
- Signed universal Release build passed (`arm64` and `x86_64`).
- Strict signature verification passed for the installed local Apple Development build.
  This is development signing, not Developer ID notarization or an App Store release.
- CPU counter deltas/wrap, RAM calculation, absent/invalid GPU readings, network timing/reset
  handling, and kernel memory-pressure levels are covered.
- Real Mach readings and stopping publication after the panel closes are covered.
- Internal/unknown-volume ejection guards, invalid capacities, actual root-volume discovery
  and volume-list uniqueness are covered. No real external disk was ejected in these tests.
- DDC checksums, short/null responses, unsupported codes and impossible values are rejected.
- Software dimming scales original color tables; mismatched tables are not treated as owned.
- Multi-display placement is bounded for positive/negative coordinates and screen edges.
- The letter M resolves to key code 41 on the test machine’s AZERTY layout.
- Real temporary sleep assertions are created/replaced/released by the tests.

### Observed UI and hardware behavior

- CPU, GPU, RAM, normal memory pressure and nonzero incoming/outgoing rates are visible in the System view.
- The root disk is listed with available/total capacity and no ejection button.
- Both built-in and external displays are discovered.
- The built-in panel exposes Apple hardware brightness. A temporary change to 90% was
  read back through the app; later user-selected brightness was preserved.
- The connected external display returned invalid DDC responses; hardware brightness
  control is **not validated** for that screen/cable combination. The app rejects those
  responses and offers labelled software image dimming instead of inventing a reading.
- A transient overlay was replaced with public display transfer-table adjustment, with
  saved-table restoration that respects subsequent changes by other apps.
- The user confirmed both the corrected panel placement and brightness changing while
  dragging, before releasing the mouse.
- The user confirmed Control + Option + M opens MacPanel. Launch at login remains enabled.
- System, Displays and Disks screenshots were captured from the real app, without desktop/chat content.
- The previous 0.1 quick-control validation covered light/dark mode, desktop icons,
  Dock/menu bar preferences, mute and awake start/stop, restoring the original settings.

### Remaining practical limits

- Real hardware DDC must be tested with a compatible monitor and connection. MonitorControl
  remains installed; this version has not demonstrated an equivalent replacement on the current external screen.
- No external-drive ejection trial or fresh login/reboot was required for this increment.
- A clean local build and signature do not prove notarized distribution or complete security.
- ColorSync, Night Shift and other brightness tools can change image transfer tables.
  Software dimming is an image adjustment, not backlight or energy-saving control.

## Repository and installation

One app is installed at `/Applications/MacPanel.app`. The working source is in
`~/Dev/MacPanel`. Generated projects, build output, local logs and test result bundles are ignored.

Only luminance-specific adaptations of MIT-licensed m1ddc code are included, with copyright
and license in source and app resources. No upstream executable, shell-based display helper,
network client, root service or new security permission was added in 0.2.

OpenDente and MonitorControl were not modified. Organize was removed at the user’s request;
Homebrew also removed dependencies it classified as unneeded. No user documents were sorted or deleted.

## 0.4.0 — 24/11/2026

- Suite native : 39 tests réussis après intégration des nouvelles fonctions. Deux tests ciblés AppUsage réussis ensuite, dont la lecture du vrai processus de test (40 cas distincts au total).
- Vérifications : ordre/visibilité et restauration des préférences ; regroupement CPU/RAM des enfants, réutilisation de PID, compteurs réels sans accès supplémentaire ; protection des volumes internes et rapport d’éjection refusée ; trames DDC volume et bornes de synchronisation.
- Release signée avec l’identité Apple Development locale existante ; aucun nouveau certificat ni accès sensible.
- Revue de cycle de vie : compteurs d’apps arrêtés panneau fermé, rubrique masquée ou autre onglet ; synchronisation opt-in suspendue en veille/verrouillage. Pas de nouvelle veille/redémarrage demandé.
- Essais physiques de synchronisation/volume et éjection d’un vrai disque : non réalisés à ce stade. Dépendent de l’écran et de volumes disponibles ; les tests ne constituent pas cette preuve.
- Sources sur feature/panel-and-display-controls. Modifications locales antérieures conservées, aucune publication ni signature Git contournée.

## 0.4.1 — 24/11/2026

- 41 tests natifs réussis, dont liaison depuis l’externe et bornes avec écart fixe positif/négatif.
- Ancien comportement reproduit dans le panneau : Mac 85 % → externe 95 %, avec écart +10 ; saturation à 100 % au-dessus de 90 % côté Mac.
- Écran actuel : transport DisplayPort, luminosité et volume sans réponse DDC/CI valide, y compris par interrogation directe du service. L’atténuation est logicielle ; Core Audio n’expose pas non plus de volume réglable pour la sortie DP Audio.
- Aucun réglage audio ni pilote ajouté. Éjection d’un vrai disque toujours non essayée, aucun disque externe disponible.

Installation et contrôle du panneau 0.4.1 (7) : externe réglé à 85 % → écran intégré lu à 75 %, puis intégré à 80 % → externe à 90 %, écart +10 points inchangé. Niveaux initiaux 100 % / 100 % rétablis. Le résultat externe est une atténuation logicielle, pas une mesure de rétroéclairage. Correction finale de l’étiquette de version pour utiliser le numéro du bundle ; Release recompilée/signée, installée et processus relancé. Pas d’autre essai matériel répété.

## 0.4.2 — 24/11/2026

- 42 tests natifs réussis. Nouveau cas : arrondi stable des écarts à un point, limites ±50 et rejet des nombres invalides.
- Release signée compilée, signature stricte validée ; copie /Applications/MacPanel.app remplacée après fermeture propre et relancée, build 8.
- Suppression du petit curseur d’écart au profit de −/+ ; les curseurs de luminosité ne modifient pas la préférence d’écart. Les saturations peuvent réduire la différence effectivement visible.
- Options de liaison et de raccourcis déplacées sous les écrans ; aucune ligne audio lorsque la capacité DDC n’est pas confirmée.
- Contrôle visuel 0.4.2 réalisé : commandes d’écran en premier, options en bas, aucune ligne audio indisponible. Écart +21 points conservé pendant externe 85 % → Mac 64 %, puis Mac 70 % → externe 91 %. Retour aux niveaux initiaux 100 % / 100 %. Aucun essai de charge/veille/redémarrage répété.
