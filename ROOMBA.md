# ROOMBA — Wartungs-Katalog

Wiederkehrende, klein gehaltene Wartungsläufe für **outlieR**. Pro Lauf wird
**genau ein** Job ausgeführt — der fällige Job mit der niedrigsten Katalognummer.

## Regeln

1. **Ein Job pro Lauf.** Kein Bündeln, kein „schnell noch das andere mit".
2. **Branch-Namen:** `roomba/<job>-<YYYY-MM-DD>`, ein Branch pro Lauf.
3. **Diff-Budget:** PRs bleiben unter **300 geänderten Zeilen**. Was nicht
   reinpasst, wird im Report als Restposten benannt statt hineingequetscht.
4. **Verhalten bleibt gleich.** Laufzeitverhalten darf nur in den Jobs
   `doc-drift`, `dead-code` und `test-flakiness` berührt werden — und auch dort
   nur, soweit es die Job-Definition ausdrücklich deckt.
5. **Report-Jobs erzeugen keinen Code-Diff.** Sie schreiben ausschließlich nach
   `.roomba/reports/<YYYY-MM-DD>-<job>.md` und aktualisieren diese Datei.
6. **Jeder Lauf** trägt unten das Datum unter „zuletzt gelaufen" nach und nennt
   den nächsten fälligen Job.
7. **Cooldown** zählt ab dem Datum des letzten Laufs, nicht ab dem Merge.

## Katalog

| # | Job | Beschreibung | Output | Cooldown |
|---|-----|--------------|--------|----------|
| 1 | `deps-audit` | Veraltete und verwundbare Dependencies (`DESCRIPTION`, GitHub Actions). Empfehlung je Fund mit ausgewiesenem Breaking-Change-Risiko. | Report | 7 d |
| 2 | `doc-drift` | README, Vignetten und roxygen-Docstrings gegen das tatsächliche Verhalten des Codes abgleichen. Dokumentation folgt dem Code, nicht umgekehrt. | PR | 14 d |
| 3 | `dead-code` | Ungenutzte Funktionen, Exporte und Imports. Jeder Fund braucht den Nachweis über eine Referenzsuche (`R/`, `tests/`, `vignettes/`, `NAMESPACE`, `man/`). | PR | 14 d |
| 4 | `error-edges` | API- und IO-Ränder ohne Fehlerbehandlung oder mit stillem Schlucken (`tryCatch` ohne Re-Raise, leere `warning`-Handler, ignorierte Rückgabewerte). | Report | 14 d |
| 5 | `test-flakiness` | Tests mit Abhängigkeit von Zeit, Zufall (fehlender Seed) oder Netz. | PR | 30 d |
| 6 | `security-footguns` | Hartkodierte Pfade, Secrets-Verdacht, Injection-Ränder (`system()`, `eval(parse())`), unsichere Defaults. **Nur Report — nie ein PR.** | Report | 14 d |
| 7 | `perf-quickwins` | Offensichtliche N+1-Muster und Kopier-Orgien; in R besonders: unnötige `data.frame`-Kopien statt `data.table`-Referenzsemantik (`set()`, `:=`). | Report | 30 d |

## Status

| # | Job | Zuletzt gelaufen | Nächste Fälligkeit | Ergebnis |
|---|-----|------------------|--------------------|----------|
| 1 | `deps-audit` | **2026-08-25** | 2026-09-01 | [Report](.roomba/reports/2026-08-25-deps-audit.md) — 7 Funde, keine Schwachstelle |
| 2 | `doc-drift` | — | fällig | — |
| 3 | `dead-code` | — | fällig | — |
| 4 | `error-edges` | — | fällig | — |
| 5 | `test-flakiness` | — | fällig | — |
| 6 | `security-footguns` | — | fällig | — |
| 7 | `perf-quickwins` | — | fällig | — |

**Nächster fälliger Job: #2 `doc-drift`** (PR, Cooldown 14 d).
