## Localizzazione FastCalc

Questa guida definisce il flusso i18n del progetto dopo l'introduzione del layer centralizzato `L10n`.

### 1. Punto di accesso unico
- Tutte le stringhe UI devono passare da `Sources/FastCalcUI/L10n.swift`.
- Non usare `NSLocalizedString` direttamente nei controller/view model, salvo casi eccezionali documentati.
- I fallback esistono solo in `L10n.swift`.

### 1.1 Risoluzione lingua a runtime (linee guida Apple)
- L'app non forza manualmente una lingua con override custom su `AppleLanguages`.
- All'avvio, `Sources/fastcalc/LocalizationBootstrap.swift` legge la configurazione effettiva tramite API Foundation:
  - `Locale.preferredLanguages`
  - `Bundle.main.localizations`
  - `Bundle.preferredLocalizations(from:forPreferences:)`
- Questo approccio rispetta il comportamento standard Apple, inclusi gli override per-app impostati in macOS (Generali > Lingua e zona > Applicazioni).

### 1.2 Layout bundle in distribuzione (.app)
- In esecuzione da `swift run`, SwiftPM mantiene le localizzazioni nel bundle risorse separato (es. `fastcalc_fastcalc.bundle`).
- In distribuzione `.app`, `buildapp.sh` copia sia:
  - il bundle risorse SwiftPM in `Contents/Resources/fastcalc_fastcalc.bundle`
  - le cartelle lingua direttamente in `Contents/Resources/*.lproj` (es. `en.lproj`, `it.lproj`)
- Questo allinea FastCalc al layout standard delle app macOS e rende robusta la risoluzione con `Bundle.main`.

### 2. Convenzione chiavi
- Formato: `feature.scope.item`.
- Esempi: `menu.item.print`, `settings.hint.hotKeyUpdated`, `roll.print.footer.pageOf`.
- Evita chiavi duplicate o varianti con casing incoerente.

### 3. Risorse lingua
- File attivi:
  - `Sources/fastcalc/Resources/en.lproj/Localizable.strings`
  - `Sources/fastcalc/Resources/it.lproj/Localizable.strings`
- `en` è lingua di riferimento.
- Ogni nuova chiave deve essere aggiunta in entrambe le lingue nello stesso commit.

### 4. Placeholder
- Usa placeholder posizionali per stringhe dinamiche: `%1$@`, `%1$d`, `%2$d`.
- Le lingue devono mantenere stessi placeholder e stessi tipi.
- Esempi in uso:
  - `menu.item.toggleWithHotKey`
  - `settings.hint.hotKeyUpdated`
  - `roll.print.footer.pageOf`

### 5. stringsdict
- Usare `Localizable.stringsdict` solo se servono plurali/varianti grammaticali reali.
- Se non è usato da chiavi runtime, non mantenerlo come file di esempio.

### 6. Checklist contributor
- Aggiungi/modifica la chiave in `L10n.swift`.
- Aggiorna EN e IT.
- Verifica assenza di hardcoded UI nei file toccati.
- Esegui `swift test`.
- Se tocchi packaging/localizzazione, esegui `./buildapp.sh` e verifica che in `dist/FastCalc.app/Contents/Resources` esistano `en.lproj` e `it.lproj`.
- Verifica manuale rapida menu, settings, popover help, popover multifunzione, export PDF.

