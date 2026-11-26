# Vorrat 🥫

Schlanke macOS-App, um Kühlschrank, Gefrierschrank und Vorräte im Blick zu behalten –
damit nichts doppelt gekauft wird und nichts vergessen wird, bis es schlecht ist.

- **Heute-Übersicht** als Startseite: Karten mit allem, was zuerst verbraucht werden sollte, vergessenen Artikeln, Rezeptideen und deiner Monatsbilanz – jeweils mit Schnellknöpfen.
- **Tabelle** mit allem, was du hast – sortierbar nach Name, Menge, Ort, Ablaufdatum, „zuletzt benutzt" …
- **Suche „Habe ich das schon?"** – durchsucht immer den ganzen Vorrat (z.B. kurz vor dem Einkauf).
- **Warnungen** in der Seitenleiste:
  - 🔴 *Abgelaufen*
  - 🟠 *Läuft bald ab* (Standard: ≤ 3 Tage)
  - 🟣 *Vergessen* – seit 30 Tagen nicht benutzt (gerechnet ab „Heute benutzt" bzw. Kaufdatum)
- **Schnellaktionen**: *Heute benutzt*, *Menge −1*, *Aufgebraucht*, *Weggeworfen* – per Toolbar, Rechtsklick oder Mehrfachauswahl. ⌘Z macht rückgängig.
- **Statistik**: verbraucht vs. weggeworfen pro Monat, Wegwerf-Quote und was am häufigsten im Müll landet.
- **Massenimport** als JSON (z.B. von einer KI aus einem Foto deines Kassenzettels) – mit Vorschau; Nachkäufe lassen sich direkt zu vorhandenen Artikeln addieren.
- **Rezeptideen** (unter *Exportieren* oder auf der Heute-Seite): erstellt einen fertigen KI-Prompt inkl. aller Zutaten – die KI darf auch Rezepte vorschlagen, für die noch etwas fehlt, und liefert dazu eine Einkaufsliste.
- **Export** als Bestandsliste (Markdown) oder JSON (Backup, wieder importierbar).

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

**Zusammenführen:** Gibt es einen ähnlichen Artikel mit derselben Einheit schon (z.B. „Vollmilch, l“), kannst du in der Vorschau „Zu Vollmilch addieren“ wählen. Bei exakt gleichem Namen ist das vorausgewählt. Die Menge wird addiert, das Kaufdatum aktualisiert und das *frühere* Ablaufdatum behalten – die alte Packung ist ja noch da.

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

**Exportieren** (⌘E) → *Rezept-Prompt* (oder auf der Heute-Seite „Rezept-Prompt erstellen“) → optional Personenzahl und Wünsche (z.B. „vegetarisch, max. 30 Minuten") eintragen → **In Zwischenablage kopieren** → bei einer KI einfügen.

Der Prompt enthält deinen kompletten Vorrat – mit allem, was bald abläuft oder vergessen wurde, unter *„Bitte bevorzugt verwenden"* ganz oben – und bittet die KI um:
- Rezepte, die möglichst viel davon verwenden,
- ausdrücklich auch Rezepte, für die noch ein paar Zutaten fehlen (jeweils mit „Muss eingekauft werden"),
- eine zusammengefasste Einkaufsliste am Ende.

## App-Icon

Liegt in `Resources/` (`AppIcon.svg` als Vorlage, `AppIcon-1024.png`, `AppIcon.icns`) und wird von `scripts/build-app.sh` automatisch eingebaut. Beim Start direkt aus Xcode zeigt das Dock das Standard-Symbol – das ist normal.

## Verbraucht oder weggeworfen?

- **Aufgebraucht** (oder *Menge −1* bis 0): zählt als verbraucht.
- **Weggeworfen**: zählt als weggeworfen – inkl. Vermerk, ob der Artikel schon abgelaufen war.
- **Löschen (Fehleingabe)** bzw. ⌫: entfernt ohne Eintrag in der Statistik.

Die Auswertung findest du in der Seitenleiste unter **Statistik**; einzelne Verlaufseinträge lassen sich dort per Rechtsklick löschen, der ganze Verlauf über den Knopf **„Statistik zurücksetzen“** in der Toolbar (mit Sicherheitsabfrage, der Vorrat bleibt unverändert).

## Einstellungen

Unter **Vorrat → Einstellungen …** (⌘,) lassen sich die Schwellen für „Läuft bald ab" und „Vergessen" anpassen.

## Projektstruktur

```
Sources/VorratCore/   Reine Logik (Import-Parser, Status-Regeln, Export, KI-Prompts) – plattformunabhängig
Sources/Vorrat/       SwiftUI + SwiftData App
Tests/                XCTest für VorratCore
Resources/            App-Icon
scripts/build-app.sh  Baut ein .app-Bundle
```
