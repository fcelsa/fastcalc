# FastCalc

FastCalc is a lightweight macOS calculator designed for fast keyboard input and a paper-roll style history.

It runs as a menu bar utility, supports a global hotkey, and keeps both window state and tape content between launches.

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

- Global toggle hotkey: recordable in Settings (custom key + modifiers, default `F16`)
- `0-9`, `.`, `,`: numeric input
- `+`, `-`, `*`, `/`, `x`: operators
- `D`: delta percentuale (variazione % tra due valori)
- `#`: inserisce una riga testo (max 20 caratteri) con operatore `#` nella colonna operatori
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

- Tag the release locally, build and package the app (build creates both `.zip` and `.dmg`):

```bash
# create an annotated tag and push it
git tag -a v1.2.3 -m "Release v1.2.3"
git push origin v1.2.3

# build and package
./release.sh v1.2.3
```

- The `release.sh` script will attempt to use the GitHub CLI (`gh`) to create a GitHub Release and upload the generated `dist/*.zip` and `dist/*.dmg`. If `gh` is not installed it will leave artifacts in `dist/` and print the `gh` command to run manually.

- Requirements for publishing: a pushed tag, signed binaries (the packaging script performs ad-hoc signing; for App Store or notarization use proper signing identities), and optionally `gh` configured with appropriate permissions.

## TODO List
- ~~Add configurable global hotkey~~
- ~~Add delta % difference calculation~~
- Add power and square root calculation ?? It's really needed ??
- Implement macro/functions management (`F` Key ?)
- Adjust copy as image for a entire roll 
- Adjust code for i18n and prepare for fast and easy l10n
- Improve status bar behaviour and functionality 
- Remove row numbering on separator — — — —
- Add save/load functionality 
- Fix the bug when delta % calculation are edited

## License

MIT License (see `LICENSE`).
