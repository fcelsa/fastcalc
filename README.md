# FastCalc

FastCalc is a lightweight macOS calculator designed for fast keyboard input and a paper-roll style history.

It runs as a menu bar utility, supports a global hotkey, and keeps both window state and tape content between launches.

## Features

- Menu bar app with quick show/hide toggle
- Global hotkey: `F16` (registered through Carbon hotkey APIs)
- Paper-roll UI with editable rows for operators, percent values, and result inputs
- Running total support with grand-total recall behavior
- Percent handling with operator-aware conversion
- Single delete reset + double delete full clear behavior
- Persistent app state (window frame, visibility, roll content, selection, scroll)
- Decimal formatting settings:
  - Floating or fixed decimals (0 to 8 places)
  - Rounding mode: down, nearest, up

## Requirements

- macOS 14+
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

- `0-9`, `.`, `,`: numeric input
- `+`, `-`, `*`, `/`, `x`: operators
- `%`: percent conversion
- `Enter` or `=` or `T`: compute result
- `M`: add GT to FIFO memory
- `R`: recall FIFO memory as operand number
- `Backspace`: delete one character from current draft input
- `Delete` (single press): reset current calculation
- `Delete` (double press within threshold): full clear (including roll)
- `Up` / `Down`: move editable row selection
- `Home` / `End`: jump to first/last editable row
- `Enter` on an editable committed row: edit row value
- `Esc` while editing: cancel edit

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

## TODO List
- Add configurable global hotkey
- Add delta % difference calculation
- Add power and square root calculation ?? It's really needed ??
- Miscellaneous... 

## License

MIT License (see `LICENSE`).