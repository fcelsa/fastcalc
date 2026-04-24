# FastCalc

FastCalc is a lightweight macOS calculator designed for fast keyboard input and a paper-roll style history.

It runs as a menu bar utility, supports a global hotkey, and keeps both window state and tape content between launches.

It doesn't have a typical on-screen input interface (numeric keypad and functions); this is its unique minimalist feature.

## Features

- Menu bar app with quick show/hide toggle
- Configurable global hotkey with custom key combinations (default: `F16`, registered through Carbon hotkey APIs)
- Paper-roll UI with editable rows for operators, percent values, and result inputs
- Running total support with grand-total recall behavior
- Percent handling with operator-aware conversion
- Single delete reset + double delete full clear behavior
- Persistent app state (window frame, visibility, roll content, selection, scroll)
- Decimal formatting settings:
  - Floating or fixed decimals (0 to 8 places)
  - Rounding mode: down, nearest, up

## Requirements

- macOS 12+
- Swift 6.2 toolchain
- Xcode or Command Line Tools

## Build From Source

1. Clone the repository and move into it:

   ```bash
   git clone <repo-url>
   cd fastcalc
   ```

2. Build the executable:

   ```bash
   swift build -c release
   ```

3. Run the app directly from SwiftPM (development mode):

   ```bash
   swift run fastcalc
   ```

## Create a Universal .app Bundle

Use the provided packaging script:

```bash
./buildapp.sh
```

The script:

- Builds release binaries for `arm64` and `x86_64`
- Merges them into a universal binary
- Creates `dist/FastCalc.app`
- Produces `dist/FastCalc-macOS-universal.zip`
- Applies ad-hoc signing to the app bundle

## Keyboard Controls

- Global toggle hotkey: recordable in Settings (custom key + modifiers, default `F16`) show/hide the interface and return the focus to the calling application (fallback on Finder/Desktop) `Esc` on normal operation do the same, without hiding application.
- `0-9`, `.`, `,`: numeric input
- `+`, `-`, `*`, `/`, `x`: operators
- `D`: Percentage delta (% change between two values)
- `%`: percent conversion
- `Enter` or `=` or `T`: compute result
- `M`: add GT to FIFO memory
- `R`: recall FIFO memory as operand number
- `S`: voice-read the numeric value on the selected row
- `Backspace`: delete one character from current draft input
- `Delete` (single press): reset current calculation
- `Delete` (double press within threshold): full clear (including roll)
- `Cmd`+`Z` full clear undo 
- `Up` / `Down`: move editable row selection
- `Home` / `End`: jump to first/last editable row
- `Enter` on an editable committed row: edit row value
- `Enter` on a `#` row: edit text value (non numeric)
- `N`: add short note (tag, label or call it whatever) on the selected row.
- `#`: add text note in the row (marked with `#` on operator column
- `Esc` while editing: cancel edit

Text rows (`#`) and label (`N`) accepted characters:
- letters and numbers
- spaces and common punctuation
- tabs/newlines/control characters are sanitized (removed or normalized)

All row with input operand are editable, recalculation is performed only for the relevant portion; also percent operation can be edited in the result row, for exampe:
73 + 10% = 80,3 
difference is 7,3 and this row can be edited and will see difference % update.


## Tests

Run the test suite with:

```bash
swift test
```

Note: the package includes `swift-testing` as an explicit dependency to support environments where `import Testing` is not available by default with Command Line Tools only.

## Resources

Place app assets (for example an `.icns` icon) in the `resources/` directory.

## Project Layout

- `Sources/FastCalcCore`: calculation logic and models
- `Sources/FastCalcUI`: app controller, window/menu bar UI, settings, formatting
- `Sources/fastcalc`: executable entry point
- `Tests/FastCalcCoreTests`: unit tests for engine and delete tracker

## Publishing a Release

Use:

```bash
./release.sh v1.2.3
```

What `release.sh` does:

1. Runs preflight checks (`swift test`, branch sync with `origin`).
2. If tag does not exist locally:
   - asks confirmation,
   - creates annotated tag,
   - pushes the tag to `origin`.
3. If tag already exists locally:
   - informs: `Tag vX.Y.Z already exists locally.`
   - asks if you want to continue in publish-only mode,
   - skips `git tag` and `git push`.
4. Builds release binaries (`arm64` and `x86_64`) and runs `buildapp.sh`.
5. Produces artifacts in `dist/` (`.zip`, `.dmg`) and writes `dist/SHA256SUMS`.
6. If `gh` is available:
   - creates or updates GitHub Release,
   - uploads/replaces assets (`--clobber`),
   - updates release notes with checksums.
7. If `gh` is not available:
   - keeps artifacts locally in `dist/`,
   - prints instructions for manual publication.

Typical workflows:

```bash
# Standard release (new tag)
./release.sh v1.2.3

# Tag already exists locally -> choose publish-only when prompted
./release.sh v1.2.3
```

Manual asset-only update (optional):

```bash
gh release upload vX.Y.Z dist/* --clobber
```

Publishing requirements: working `git` remote, valid release tag version, and optionally `gh` authenticated with permissions to create/edit releases.

## Note per utenti che scaricano binari non notarizzati

Se scarichi un `.zip` o `.dmg` dalla sezione `dist/` (o da una release non notarizzata), macOS potrebbe bloccare l'apertura dell'app tramite Gatekeeper. Opzioni sicure e consigli pratici:

- **Verifica il checksum**: confronta l'hash SHA‑256 dell'artefatto scaricato con quello pubblicato dal maintainer prima di aprirlo.

```bash
# Esempio: calcola SHA-256 del DMG o ZIP scaricato
shasum -a 256 FastCalc-macOS-universal.zip
shasum -a 256 FastCalc-1.2.3-macOS-universal.dmg
```

- **Apri usando il Finder (consigliato per utenti non esperti)**:
   - Ctrl‑clic (o clic destro) sull'app e scegli "Apri"; nella finestra di dialogo che appare conferma l'apertura.
   - Se il pulsante "Apri comunque" è richiesto, vai in `Impostazioni di Sistema > Privacy e Sicurezza` e autorizza l'app temporaneamente.

- **Metodi da terminale (per utenti avanzati)**:
   - Rimuovere l'attributo di quarantena (sblocca l'app):

```bash
# rimuove l'attributo di quarantena dall'app o dal bundle
xattr -rd com.apple.quarantine /percorso/alla/FastCalc.app
```

   - In alternativa aggiungere al sistema come applicazione attendibile (meno consigliato senza firma valida):

```bash
sudo spctl --add /percorso/alla/FastCalc.app
```

- **Avvertenze**:
   - Non disabilitare permanentemente Gatekeeper (`spctl --master-disable`) su macchine di produzione o personali condivise.
   - Preferisci sempre scaricare artefatti da fonti fidate e verificare checksum/firming prima di concedere permessi.


## TODO List
- ~~Add configurable global hotkey~~
- ~~Add delta % difference calculation~~
- Add power and square root calculation ?? It's really needed ??
- Implement macro/functions management (`F` Key ?)
- ~~Adjust copy as image for a entire roll~~
- Adjust code for i18n and prepare for fast and easy l10n
- Improve status bar behaviour and functionality 
- ~~Remove row numbering on separator — — — —~~
- Add save/load functionality 
- ~~Fix the bug when delta % calculation are edited~~

## License

MIT License (see `LICENSE`).
