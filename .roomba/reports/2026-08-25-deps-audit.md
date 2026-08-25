# roomba · deps-audit · 2026-08-25

**Job:** #1 `deps-audit` · **Output:** Report (kein Code-Diff) · **Cooldown:** 7 d
**Scope:** `DESCRIPTION`, `NAMESPACE`, `.github/workflows/*.yaml`, `pkg::`-Nutzung in `R/`, `tests/`, `vignettes/`

## Kurzfassung

**Keine bekannte Sicherheitslücke** in einer der neun deklarierten Dependencies.
Das eigentliche Risiko liegt woanders: Das Paket pinnt keine einzige Untergrenze
(außer `testthat`), und die CI, die diese Annahme absichern würde, ist seit
**9 Monaten nicht mehr gelaufen**. Der grüne Haken auf `main` gilt für einen
Dependency-Stand von November 2025, nicht für den von heute.

7 Funde: 2 hoch, 2 mittel, 3 niedrig.

## Bestand

| Paket | Deklariert | Aktuell (CRAN) | Rolle |
|---|---|---|---|
| `isotree` | *keine Grenze* | 0.6.1-5 | Imports — Kern-Algorithmus |
| `data.table` | *keine Grenze* | 1.18.4 | Imports — internes Datenmodell |
| `ggplot2` | *keine Grenze* | 4.0.x | Imports — gesamte Visualisierung |
| `cli` | *keine Grenze* | 3.6.6 | Imports — Konsolenausgabe + Fehler |
| `patchwork` | *keine Grenze* | 1.3.2 | Imports — 1 Aufruf (`wrap_plots`) |
| `withr` | *keine Grenze* | aktuell | Imports — 1 Aufruf (`local_seed`) |
| `parallel`, `stats`, `utils` | — | Base R | Imports — Basisdistribution |
| `testthat` | `>= 3.0.0` | 3.3.2 | Suggests — einzige gepinnte Dep |
| `knitr`, `rmarkdown`, `spelling` | *keine Grenze* | aktuell | Suggests |

Kein `renv.lock` — für ein CRAN-Paket korrekt so. Pakete pinnen nach unten, nicht fest.

## Funde

### F1 · hoch · CI ist seit 9 Monaten nicht gelaufen

`R-CMD-check.yaml` triggert nur auf `push` (main/master) und `pull_request`.
Kein `schedule:`. Letzter Lauf: Run #16 vom **2025-11-08**, grün.

Damit ist die einzige Absicherung gegen Upstream-Drift an Commit-Aktivität
gekoppelt — und die gab es seit November nicht. Seither sind unter anderem
`data.table` 1.18.x, `cli` 3.6.6, `patchwork` 1.3.2, `isotree` 0.6.1-5 und
R 4.6.x erschienen. Ob das Paket gegen diesen Stand baut, ist schlicht unbekannt.
Zusammen mit F2 (keine Obergrenzen, keine Untergrenzen) heißt das: Jeder
Nutzer installiert gegen einen Stack, den nie jemand getestet hat.

**Empfehlung:** wöchentlichen Cron-Trigger ergänzen.

```yaml
on:
  push:
    branches: [main, master]
  pull_request:
  schedule:
    - cron: "0 4 * * 1"     # montags 04:00 UTC
```

**Breaking-Change-Risiko: keins.** Reine CI-Konfiguration, kein Paketcode.
Vier Zeilen. Das ist der Fund mit dem besten Aufwand-Nutzen-Verhältnis im
ganzen Report.

### F2 · hoch · Keine Versionsuntergrenzen in `Imports`

`DESCRIPTION:16-25` listet neun Imports ohne jede Versionsangabe. Das ist nicht
nur formal unsauber — es gibt mindestens einen Aufruf, der nachweisbar eine
neuere API voraussetzt:

`R/detect_outliers.R:104-107` übergibt an `isotree::isolation.forest()`:

```r
prob_pick_full_gain = 1.0,
prob_pick_dens      = 0.0,
```

Beide Argumente sind in der aktuellen `isotree`-Dokumentation vorhanden, gehören
aber zu den später ergänzten Split-Kriterien und existieren in den frühen
0.x-Releases nicht. Ein Nutzer mit einer älteren `isotree`-Installation bekommt
kein sauberes Dependency-Resolution-Fehlerbild, sondern einen
`unused argument`-Laufzeitfehler mitten in `detect_outliers()`.

Zweiter Fall: `cli::cli_abort()` (7 Stellen in `R/`) wurde mit cli 3.0.0
eingeführt und ist unter cli 2.x nicht verfügbar.

**Empfehlung:** Untergrenzen setzen. Vor dem Festschreiben der `isotree`-Grenze
kurz gegen dessen NEWS prüfen, ab welchem Release `prob_pick_full_gain` und
`prob_pick_dens` existieren — der Report konnte das aus der Distanz nicht
abschließend belegen und rät nicht.

```
Imports:
    cli (>= 3.0.0),
    data.table (>= 1.14.0),
    ggplot2 (>= 3.4.0),
    isotree (>= 0.5.0),        # ← Grenze gegen isotree-NEWS verifizieren
    ...
```

**Breaking-Change-Risiko: niedrig.** Untergrenzen sind für Nutzer rein
restriktiv — bestehende, funktionierende Installationen bleiben gültig, nur
zu alte werden jetzt ehrlich abgelehnt statt später zu crashen. Vorsicht nur
bei der Höhe: eine zu hoch angesetzte Grenze schließt Nutzer ohne Not aus.

### F3 · mittel · Snapshot-Test koppelt die Suite an cli's Fehlerformatierung

`tests/testthat/_snaps/detect_outliers.md` speichert eine wörtliche
cli-Fehlerausgabe:

```
    Condition
      Error in `validate_inputs()`:
      ! `data` must be a data.frame or data.table
```

Der Snapshot hängt damit an cli's Rendering von `cli_abort()` — Prefix, Umbruch,
Bullet-Zeichen inklusive. Ändert cli daran etwas, wird der Test rot, ohne dass
sich am Verhalten von `outlieR` irgendetwas geändert hätte. Aktuell ist genau
eine Snapshot-Datei betroffen, das Risiko ist begrenzt, wächst aber mit jedem
weiteren Snapshot mit.

**Empfehlung:** beobachten, nicht jetzt umbauen. Falls die Datei wächst, für
Fehlerfälle auf `expect_error(..., class = ...)` statt Snapshots wechseln.
Gehört inhaltlich zu Job #5 `test-flakiness`, dort vormerken.

**Breaking-Change-Risiko: keins** (Testcode). Ein Umbau wäre allerdings ein
Verhaltenstest-Umbau und braucht die passende Job-Zuständigkeit.

### F4 · mittel · `R (>= 4.1.0)` wird von keinem CI-Job abgedeckt

`DESCRIPTION:15` deklariert R >= 4.1.0. Die CI-Matrix fährt `devel`, `release`
und `oldrel-1`. Mit R 4.6.x als aktuellem Release liegt `oldrel-1` bei ~4.5.x —
zwischen der deklarierten Untergrenze und dem ältesten getesteten R liegen
mehrere Minor-Versionen. Die Zusage „läuft ab 4.1" ist unbelegt.

**Empfehlung:** eine der beiden Richtungen, nicht beide:

* *ehrlich testen* — Matrix-Eintrag `{os: ubuntu-latest, r: '4.1'}` ergänzen; oder
* *ehrlich zusagen* — Floor auf das anheben, was die Dependencies ohnehin
  erzwingen, und in `NEWS.md` vermerken.

**Breaking-Change-Risiko: Matrix-Eintrag = keins. Floor anheben = mittel** —
das schließt Nutzer auf altem R aus und gehört in einen Release-Eintrag, nicht
still in einen Wartungs-PR.

### F5 · niedrig · GitHub Actions veraltet

| Action | Verwendet | Stand |
|---|---|---|
| `actions/checkout` | `@v4` (3×) | mindestens zwei Majors zurück (v5, laut Suche bereits v6) |
| `JamesIves/github-pages-deploy-action` | `@v4.5.0` | auf einen Patch festgenagelt, bekommt keine Fixes |
| `codecov/codecov-action` | `@v5` | aktuell |
| `r-lib/actions/*` | `@v2` | aktuell (v2 ist die gepflegte Linie) |
| `actions/upload-artifact` | `@v4` | aktuell |

**Empfehlung:** `checkout` auf die aktuelle Major heben (vorher die reale
Major-Nummer prüfen, die Suche war hier nicht eindeutig),
`github-pages-deploy-action` von `@v4.5.0` auf `@v4` lockern.

**Breaking-Change-Risiko: niedrig.** `checkout` v5+ setzt eine neuere
Node-Runtime voraus; auf GitHub-hosted Runnern ist das gegeben. Kein Paketcode
betroffen.

### F6 · niedrig · `remotes` in der Vignette nicht deklariert

`vignettes/getting-started.Rmd:34` nutzt `remotes::install_github()`. Der Chunk
ist `eval=FALSE`, wird von knitr beim Tangeln aber trotzdem erfasst, und
R CMD check kann das als „Undeclared package in vignette"-NOTE melden. Da
`check-r-package@v2` standardmäßig erst bei WARNING abbricht, wäre eine solche
NOTE in den grünen Läufen untergegangen.

**Empfehlung:** die Zeile analog zur Nachbarzeile auskommentieren
(`# remotes::install_github("fabiandistler/outlieR")` steht direkt neben dem
bereits auskommentierten `# install.packages("remotes")`), statt `remotes` nur
für eine Beispielzeile in `Suggests` aufzunehmen. Gehört zu Job #2 `doc-drift`.

**Breaking-Change-Risiko: keins.**

### F7 · niedrig · `withr` als Import für einen einzigen Aufruf

`withr` steht in `Imports`, wird in `R/` aber genau einmal benutzt:
`R/detect_outliers.R:65` — `withr::local_seed(seed)`. In `tests/` kommen zwei
weitere Aufrufe dazu, die über `Suggests` gedeckt wären.

**Empfehlung: nichts tun.** `withr` ist leichtgewichtig, hat selbst keine
Dependencies und ist über `testthat` ohnehin transitiv vorhanden. Ein Ersatz
durch manuelles `.Random.seed`-Handling würde die RNG-Semantik der öffentlichen
API anfassen — genau das, was die roomba-Regeln für einen Report-Job ausschließen.
Hier nur als bewusste Entscheidung dokumentiert, damit der nächste Lauf nicht
neu darüber nachdenkt.

**Breaking-Change-Risiko einer Umsetzung: mittel** (Seed-Semantik). Deshalb: nicht.

## Schwachstellen

Keine. Die R-Ökosystem-Lage unterscheidet sich hier von npm oder PyPI: Es gibt
keinen CVE-Feed für CRAN-Pakete, gegen den sich automatisiert prüfen ließe, und
für keine der neun Dependencies ist ein Sicherheitsproblem bekannt. Der
Angriffsvektor eines reinen Analysepakets ohne Netzwerk-, Datei- oder
Prozess-IO ist ohnehin schmal.

Ein Rand bleibt: `parallel::makeCluster()` in `R/tuning.R` öffnet
PSOCK-Verbindungen auf localhost. Das ist Standard-R-Verhalten und keine
Dependency-Frage — die Bewertung gehört zu Job #6 `security-footguns`.

## Empfohlene Reihenfolge

1. **F1** — Cron-Trigger. Vier Zeilen, kein Risiko, macht alle weiteren Funde
   überhaupt erst laufend beobachtbar.
2. **F2** — Untergrenzen, nach Verifikation der `isotree`-Grenze.
3. **F5** — Action-Bumps, als Beifang zu F1 im selben Workflow-PR.
4. **F4** — Entscheidung Matrix vs. Floor; braucht eine bewusste Wahl.
5. **F6** — mitnehmen in `doc-drift`.
6. **F3** — vormerken für `test-flakiness`.
7. **F7** — erledigt, dokumentiert, kein Handlungsbedarf.

## Methodik und Grenzen

Ehrlich zur Belastbarkeit dieses Reports:

* **Kein R in der Session.** Weder `R` noch `Rscript` sind installiert. Es gab
  also keine `R CMD check`-Ausführung, kein `devtools::test()`, keine
  Auflösung des tatsächlichen Dependency-Graphen — die Analyse ist statisch
  (Quelltext, `DESCRIPTION`, `NAMESPACE`, Workflow-YAML).
* **CRAN war nicht direkt erreichbar.** Der Egress-Proxy blockiert
  `cran.r-project.org`, `cloud.r-project.org`, `r-pkg.org` und
  `packagemanager.posit.co`. Die Versionsstände in der Bestandstabelle stammen
  aus Websuche und sind in den Patch-Levels und Veröffentlichungsdaten teils
  widersprüchlich. Für die Aussage „deutlich neuer als der zuletzt getestete
  Stand" reicht das; als Grundlage für ein exaktes Pinning **nicht** — vor dem
  Umsetzen von F2 und F5 die Zahlen gegen CRAN beziehungsweise die
  Action-Repos gegenprüfen.
* **CI-Historie** kam über die GitHub-API und ist belastbar: 16 Läufe,
  letzter am 2025-11-08, Runs #1–#5 rot, ab #6 durchgehend grün.
* **Codeseitige Aussagen** (isotree-Argumente, cli-Aufrufe, ggplot2-API,
  Snapshot-Inhalt, `withr`-Nutzung) sind direkt am Quelltext verifiziert und
  jeweils mit Datei und Zeile belegt.

Als Nebenergebnis der ggplot2-Prüfung: Der Visualisierungscode nutzt **keine**
der in ggplot2 4.0.0 deprecateten APIs — kein `aes_string()`, kein `borders()`,
kein `geom_errorbarh()`, kein `fatten`-Argument, kein numerisches
`legend.position`, kein `$data`-Zugriff auf ggplot-Objekte. Die `size`-Argumente
in `R/visualization.R` stehen durchweg an Punkt-Geomen und `element_text()`,
sind also nicht von der `linewidth`-Umstellung betroffen. Der größte
Einzel-Dependency-Sprung des Zeitraums trifft dieses Paket damit nicht.
