
<!-- README.md is generated from README.Rmd. Please edit that file -->

# outlieR

<!-- badges: start -->

<!-- badges: end -->

# outlieR <img src="man/figures/logo.png" align="right" height="139" />

> Automatic Outlier Detection Using Isolation Forests

[![R-CMD-check](https://github.com/yourusername/outlieR/workflows/R-CMD-check/badge.svg)](https://github.com/yourusername/outlieR/actions)
[![Codecov test
coverage](https://codecov.io/gh/yourusername/outlieR/branch/main/graph/badge.svg)](https://codecov.io/gh/yourusername/outlieR?branch=main)
[![CRAN
status](https://www.r-pkg.org/badges/version/outlieR)](https://CRAN.R-project.org/package=outlieR)

## Übersicht

`outlieR` bietet eine einfache, leistungsstarke API zur automatischen
Erkennung von Ausreißern in tabellarischen Daten. Das Package nutzt
Isolation Forests (via `isotree`) mit automatischem
Hyperparameter-Tuning und liefert detaillierte Diagnosen auf
Feature-Ebene.

### Hauptfeatures

✨ **Einfache API** - Eine Funktion für die meisten Anwendungsfälle 🎯
**Automatisches Tuning** - Grid Search, Random Search oder Bayesian
Optimization  
📊 **Detaillierte Diagnostik** - Feature-Level Outlier-Analyse 📈
**Umfangreiche Visualisierungen** - Score-Plots, Feature Importance,
PCA-Projektion ⚡ **data.table Design** - Effiziente Datenverarbeitung
🔧 **Flexibel** - Unterstützt numerische und kategoriale Variablen

## Installation

``` r
# Von GitHub installieren (Development Version)
# install.packages("remotes")
remotes::install_github("yourusername/outlieR")

# Von CRAN installieren (sobald verfügbar)
# install.packages("outlieR")
```

## Quick Start

``` r
library(outlieR)

# Basis-Verwendung: Automatische Outlier-Erkennung
result <- detect_outliers(mtcars)

# Ergebnisse anzeigen
print(result)
summary(result)

# Outlier-Details extrahieren
outlier_summary <- get_outlier_summary(result)
head(outlier_summary)

# Visualisierungen erstellen
plot(result, type = "score")       # Score-Verteilung
plot(result, type = "features")    # Feature Importance
plot(result, type = "pca")         # PCA-Projektion
plot(result, type = "all")         # Alle Plots
```

## Detaillierte Beispiele

### 1. Spezifische Spalten analysieren

``` r
# Nur ausgewählte Variablen verwenden
result <- detect_outliers(
  data = iris,
  target_cols = c("Sepal.Length", "Sepal.Width", "Petal.Length"),
  contamination = 0.05  # Erwarte 5% Outliers
)
```

### 2. Ohne automatisches Tuning

``` r
# Manuelle Parameter-Spezifikation für mehr Kontrolle
result <- detect_outliers(
  data = mtcars,
  tune = FALSE,
  n_trees = 200,
  max_depth = 12,
  sample_size = 512
)
```

### 3. Verschiedene Tuning-Methoden

``` r
# Grid Search (default, systematisch aber langsamer)
result_grid <- detect_outliers(mtcars, tune_method = "grid")

# Random Search (schneller, gute Ergebnisse)
result_random <- detect_outliers(mtcars, tune_method = "random")

# Bayesian Optimization (experimentell)
result_bayes <- detect_outliers(mtcars, tune_method = "bayesian")
```

### 4. Mit kategorischen Variablen

``` r
# Automatische One-Hot-Encoding von Faktoren
data <- data.frame(
  value1 = rnorm(100),
  value2 = rnorm(100),
  category = sample(c("A", "B", "C"), 100, replace = TRUE)
)

result <- detect_outliers(data)
```

### 5. Detaillierte Outlier-Analyse

``` r
result <- detect_outliers(mtcars)

# Welche Zeile ist ein Outlier?
outliers <- get_outlier_summary(result, detailed = FALSE)
print(outliers)
#   row_id anomaly_score n_outlier_features
# 1     31         1.234                  3
# 2     17         1.156                  2

# Welche Features sind in Zeile 31 auffällig?
detailed <- get_outlier_summary(result, detailed = TRUE)
detailed[row_id == 31]
```

## Workflow-Beispiel: Komplette Analyse

``` r
library(outlieR)
library(data.table)

# 1. Daten laden
data <- fread("your_data.csv")

# 2. Outlier-Erkennung mit Tuning
result <- detect_outliers(
  data = data,
  contamination = 0.1,
  tune = TRUE,
  tune_method = "random",
  parallel = TRUE,
  verbose = TRUE
)

# 3. Modell-Performance prüfen
print(result)
# Zeigt: Anzahl Outliers, verwendete Parameter, Metriken

# 4. Top Outliers identifizieren
top_outliers <- get_outlier_summary(result)[1:10]
print(top_outliers)

# 5. Visualisierungen erstellen
plots <- plot(result, type = "all")

# 6. Outlier-Zeilen extrahieren für weitere Analyse
outlier_rows <- data[result$outliers, ]

# 7. Outlier-Details als data.table für Weiterverarbeitung
outlier_dt <- data.table::as.data.table(result$outlier_details)
outlier_dt[is_outlier == TRUE, .N, by = n_outlier_features]
```

## API-Referenz

### Hauptfunktion

#### `detect_outliers()`

Hauptfunktion zur Outlier-Erkennung.

**Parameter:** - `data`: data.frame oder data.table mit den Daten -
`target_cols`: Character-Vektor mit Spaltennamen (NULL = alle
numerischen) - `contamination`: Erwarteter Outlier-Anteil (0-1, default:
0.1) - `tune`: Soll automatisches Tuning durchgeführt werden? (default:
TRUE) - `tune_method`: “grid”, “random”, oder “bayesian” (default:
“grid”) - `n_trees`: Anzahl Bäume im Isolation Forest (default: 100) -
`sample_size`: Sample-Größe pro Baum (default: “auto”) - `max_depth`:
Maximale Baumtiefe (default: “auto”) - `seed`: Random Seed für
Reproduzierbarkeit - `parallel`: Parallele Verarbeitung beim Tuning?
(default: TRUE) - `verbose`: Progress-Meldungen anzeigen? (default:
TRUE)

**Rückgabewert:** Objekt der Klasse `outlier_detector` mit: - `model`:
Trainiertes isotree-Modell - `scores`: Anomaly Scores für jede
Beobachtung - `outliers`: Logischer Vektor mit Outlier-Status -
`outlier_details`: data.table mit detaillierter Feature-Analyse -
`threshold`: Verwendeter Score-Threshold - `params`: Verwendete
Modell-Parameter - `metrics`: Performance-Metriken - `preprocessing`:
Informationen zur Daten-Vorverarbeitung

### Hilfsfunktionen

#### `get_outlier_summary(x, detailed = TRUE)`

Extrahiert Outlier-Zusammenfassung aus Ergebnisobjekt.

#### `plot(x, type = "score", n_top = 10, ...)`

Erstellt Visualisierungen. Typen: - `"score"`: Score-Verteilung über
alle Beobachtungen - `"features"`: Feature Importance für Outliers -
`"distribution"`: Histogramm der Scores nach Klasse - `"pca"`:
PCA-Projektion mit Outlier-Markierung - `"heatmap"`:
Feature-Score-Heatmap für Top-Outliers - `"all"`: Alle Plots kombiniert

## Design-Prinzipien

### data.table-Stil

``` r
# Effiziente Operationen mit data.table
result <- detect_outliers(your_data)
dt <- data.table::as.data.table(result$outlier_details)

# Analyze by reference
dt[is_outlier == TRUE, summary_stat := mean(anomaly_score)]
dt[, .N, by = .(is_outlier, n_outlier_features)]
```

### Tidy Design

- **Konsistente API**: Eine Hauptfunktion mit klaren Parametern
- **Pipes-ready**: Funktioniert mit `|>` und `%>%`
- **Informative Ausgaben**: Klare Print- und Summary-Methoden
- **Flexibilität**: Viele Optionen, aber sinnvolle Defaults

## Performance

``` r
# Benchmark auf verschiedenen Datengrößen
library(bench)

# Kleiner Datensatz (1000 Zeilen)
small_data <- data.frame(matrix(rnorm(1000 * 10), ncol = 10))
mark(detect_outliers(small_data, tune = FALSE))
# ~500ms

# Mittlerer Datensatz (10000 Zeilen)
medium_data <- data.frame(matrix(rnorm(10000 * 10), ncol = 10))
mark(detect_outliers(medium_data, tune = FALSE))
# ~2s

# Mit Tuning (langsamer, aber bessere Ergebnisse)
mark(detect_outliers(medium_data, tune = TRUE, tune_method = "random"))
# ~20s (parallel auf 4 Cores)
```

## Erweiterte Verwendung

### Custom-Threshold

``` r
result <- detect_outliers(mtcars, contamination = 0.05)

# Eigenen Threshold verwenden
custom_threshold <- quantile(result$scores, 0.99)
custom_outliers <- result$scores > custom_threshold

# Neue Details generieren
result$outliers <- custom_outliers
result$threshold <- custom_threshold
```

### Integration mit anderen Packages

``` r
# Mit data.table Workflows
library(data.table)
dt <- as.data.table(mtcars)
result <- detect_outliers(dt)
dt[, is_outlier := result$outliers]
dt[is_outlier == TRUE, .SD, .SDcols = c("mpg", "cyl", "disp")]

# Mit ggplot2 für Custom Plots
library(ggplot2)
plot_data <- data.table(
  index = seq_along(result$scores),
  score = result$scores,
  outlier = result$outliers
)
ggplot(plot_data, aes(x = index, y = score, color = outlier)) +
  geom_point()
```

## Troubleshooting

### Zu viele/wenige Outliers

``` r
# Contamination-Parameter anpassen
result <- detect_outliers(data, contamination = 0.05)  # Weniger Outliers
result <- detect_outliers(data, contamination = 0.15)  # Mehr Outliers
```

### Schlechte Trennung

``` r
# Mehr Bäume verwenden
result <- detect_outliers(data, n_trees = 300)

# Tuning aktivieren für bessere Parameter
result <- detect_outliers(data, tune = TRUE, tune_method = "random")
```

### Memory-Probleme bei großen Daten

``` r
# Paralleles Processing deaktivieren
result <- detect_outliers(large_data, parallel = FALSE)

# Weniger Bäume
result <- detect_outliers(large_data, n_trees = 50, tune = FALSE)
```

## Roadmap

- [ ] Support für mehr Tuning-Algorithmen (Bayesian Optimization
  vollständig)
- [ ] Integration mit mlr3
- [ ] Streaming-Outlier-Detection
- [ ] Shapley-Values für Feature-Attribution
- [ ] Automatische Outlier-Bereinigung/Imputation
- [ ] Time-Series Outlier Detection
- [ ] Multi-Modal Distribution Support

## Mitwirken

Contributions sind willkommen! Bitte:

1.  Fork das Repository
2.  Erstelle einen Feature-Branch
    (`git checkout -b feature/AmazingFeature`)
3.  Committe deine Änderungen
    (`git commit -m 'Add some AmazingFeature'`)
4.  Push zum Branch (`git push origin feature/AmazingFeature`)
5.  Öffne einen Pull Request

## Lizenz

MIT License - siehe [LICENSE](LICENSE) Datei für Details.

## Zitierung

``` bibtex
@software{outlieR2024,
  author = {Distler, Fabian},
  title = {outlieR: Automatic Outlier Detection Using Isolation Forests},
  year = {2024},
  url = {https://github.com/yourusername/outlieR}
}
```

## Danksagungen

- `isotree` Package für die Isolation Forest Implementierung
- `data.table` für effiziente Datenverarbeitung
- R Community für Feedback und Inspiration
