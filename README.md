# Vorrat 🥫

Schlanke macOS-App, um Kühlschrank, Gefrierschrank und Vorräte im Blick zu behalten –
damit nichts doppelt gekauft wird und nichts vergessen wird, bis es schlecht ist.

- **Tabelle** mit allem, was du hast – sortierbar nach Name, Menge, Ort, Ablaufdatum, „zuletzt benutzt" …
- **Suche „Habe ich das schon?"** – durchsucht immer den ganzen Vorrat (z.B. kurz vor dem Einkauf).
- **Warnungen** in der Seitenleiste:
  - 🔴 *Abgelaufen*
  - 🟠 *Läuft bald ab* (Standard: ≤ 3 Tage)
  - 🟣 *Vergessen* – seit 30 Tagen nicht benutzt (gerechnet ab „Heute benutzt" bzw. Kaufdatum)
- **Schnellaktionen**: *Heute benutzt*, *Menge −1*, *Aufgebraucht* – per Toolbar, Rechtsklick oder Mehrfachauswahl. ⌘Z macht rückgängig.
- **Massenimport** als JSON (z.B. von einer KI aus einem Foto deines Kassenzettels) – mit Vorschau und Hinweis „schon im Vorrat".
- **Export** als Markdown (ideal, um eine KI nach Rezepten zu fragen) oder JSON (Backup, wieder importierbar).

Alle Daten bleiben lokal auf deinem Mac (`~/Library/Application Support/Vorrat/`).

## Starten

Voraussetzung: macOS 14 (Sonoma) oder neuer und Xcode 15+ (bzw. die Xcode Command Line Tools).

**Variante A – Xcode:** `Package.swift` doppelklicken → oben das Schema **Vorrat** und „My Mac" wählen → ▶︎ Run.

**Variante B – fertige App bauen:**

```bash
./scripts/build-app.sh
```

```bash
mv build/Vorrat.app /Applications/
```

**Tests der Kernlogik** (Import, Export, Status-Regeln):

```bash
swift test
```

## Einkauf per KI importieren

1. In der App **Importieren** (⌘I) → **KI-Prompt kopieren**.
2. Prompt + Foto vom Kassenzettel an eine KI deiner Wahl schicken.
3. Antwort kopieren → **Aus Zwischenablage einfügen** → Vorschau prüfen → **Übernehmen**.

Man kann auch eine `.json`-Datei aufs Fenster ziehen. Ein Beispiel liegt in [`examples/einkauf-beispiel.json`](examples/einkauf-beispiel.json).

### Format

```json
{
  "items": [
    {
      "name": "Vollmilch",
      "category": "Milchprodukte",
      "location": "Kühlschrank",
      "quantity": 2,
      "unit": "l",
      "purchaseDate": "2026-11-26",
      "expiryDate": "2026-12-05",
      "notes": "optional"
    }
  ]
}
```

| Feld | Pflicht | Standard | Hinweise |
|---|---|---|---|
| `name` | ja | – | |
| `category` | nein | `Sonstiges` | freier Text |
| `location` | nein | `Vorratsschrank` | `Kühlschrank`, `Gefrierschrank`, `Vorratsschrank`, `Sonstiges` oder eigener Ort; `fridge`/`freezer`/`pantry` werden erkannt |
| `quantity` | nein | `1` | Zahl oder Text wie `"1,5"` |
| `unit` | nein | `Stk` | |
| `purchaseDate` | nein | heute | `YYYY-MM-DD`, `TT.MM.JJJJ` oder ISO 8601 |
| `expiryDate` | nein | – | dito |
| `openedDate`, `lastUsedDate`, `notes` | nein | – | |

Der Import ist bewusst tolerant: ein reines Array `[ … ]` geht auch, Text oder ```` ```json ````-Blöcke rund um das JSON werden ignoriert, und deutsche Feldnamen (`menge`, `einheit`, `ort`, `kaufdatum`, `mhd`, …) funktionieren ebenfalls. Fehlerhafte Einträge werden in der Vorschau angezeigt statt den ganzen Import abzubrechen.

## Rezepte vorschlagen lassen

**Exportieren** (⌘E) → Format *Markdown* → „Rezept-Prompt voranstellen" anlassen → **In Zwischenablage kopieren** → bei einer KI einfügen.
Der Export listet oben alles unter *„Bitte bevorzugt verwenden"*, was bald abläuft oder vergessen wurde.

## Einstellungen

Unter **Vorrat → Einstellungen …** (⌘,) lassen sich die Schwellen für „Läuft bald ab" und „Vergessen" anpassen.

## Projektstruktur

```
Sources/VorratCore/   Reine Logik (Import-Parser, Status-Regeln, Export, KI-Prompts) – plattformunabhängig
Sources/Vorrat/       SwiftUI + SwiftData App
Tests/                XCTest für VorratCore
scripts/build-app.sh  Baut ein .app-Bundle
```
