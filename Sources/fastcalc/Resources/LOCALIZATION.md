## Localizzazione — guida rapida

Questa breve guida spiega le convenzioni usate nel progetto per i file di localizzazione `.lproj`, come organizzare le chiavi, e approfondisce l'uso di `.stringsdict` per i plurali e le varianti locali.

1) Posizione dei file
- Metti i file di lingua sotto `Sources/<Target>/Resources/<locale>.lproj/` (es. `Sources/fastcalc/Resources/en.lproj/`). SwiftPM include automaticamente `Resources` nei bundle dei target.

2) Formato e encoding
- File `.strings`: sintassi `"key" = "value";`.
- Xcode storicamente preferisce UTF-16 con BOM; strumenti moderni (e `swift build`) funzionano anche con UTF-8, ma conservare UTF-16 evita incompatibilità con tooling Apple.

3) Commenti e contesto per i traduttori
- Usa commenti C-style `/* ... */` prima della stringa per fornire contesto. I commenti possono essere generati automaticamente con `genstrings` o con tool di estrazione.
- Includi dove possibile uno screenshot o una breve nota su dove la stringa è mostrata.

4) Convenzioni chiavi
- Usa chiavi semantiche/gerarchiche (es. `help.section.input`).
- Mantieni `en.lproj/Localizable.strings` come sorgente di riferimento.

5) Placeholder
- Usa specificatori posizionali quando servono riordinamenti: `%1$@`, `%2$d`.
- Documenta i placeholder con commenti (es. `/* %1$@ = user name */`).

6) Workflow e automazione
- Strumenti utili: `genstrings`, `SwiftGen`, `BartyCrouch`, servizi di localizzazione (Crowdin, Lokalise, ecc.).
- Aggiungi un `Resources/LOCALIZATION.md` (questo) con regole e comandi per i contributori.

7) `.stringsdict` — approfondimento
.stringsdict è il formato usato per gestire plurali e varianti locali complesse. È un file plist che mappa una chiave a regole di pluralizzazione (e altre regole di format). Esempi d'uso:

- Chiave in `Localizable.strings`:
  "files.count" = "%#@files@";

- Corrispondente `Localizable.stringsdict` (esempio per inglese):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>files.count</key>
  <dict>
    <key>NSStringLocalizedFormatKey</key>
    <string>%#@files@</string>
    <key>files</key>
    <dict>
      <key>NSStringFormatSpecTypeKey</key>
      <string>NSStringPluralRuleType</string>
      <key>NSStringFormatValueTypeKey</key>
      <string>d</string>
      <key>one</key>
      <string>1 file</string>
      <key>other</key>
      <string>%d files</string>
    </dict>
  </dict>
</dict>
</plist>
```

- Come usarlo in codice (Swift):

```swift
let count = 3
let format = NSLocalizedString("files.count", comment: "Number of files")
let message = String.localizedStringWithFormat(format, count)
```

- Nota: per lingue con regole più complesse (es. russo, arabo), `.stringsdict` permette di definire le forme richieste dal linguaggio.

8) Test e CI
- Aggiungi un job CI che verifica che tutte le chiavi usate nel codice esistano in `en.lproj` e che i placeholder coincidano (es. con uno script o `BartyCrouch lint`).

