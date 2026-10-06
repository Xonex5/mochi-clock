# Chrono

Plugin tout-en-un pour Mochi réunissant une horloge, un chronomètre et un minuteur.

## Fonctionnalités

- Horloge : affiche l'heure courante (format 24h ou 12h) avec les secondes, la date complète et le pourcentage de la journée écoulée.
- Chronomètre : mesure le temps au dixième de seconde près avec enregistrement des tours (split et cumul).
- Minuteur : compte à rebours paramétrable avec anneau de progression, boutons de préréglages (1m, 3m, 5m, 10m, 15m, 25m), alertes sur l'îlot central et notification sonore.
- Bulle dynamique : affiche le décompte ou le chrono actif à côté de l'îlot. Cliquer sur la bulle met en pause ou reprend le décompte.
- Intégration Hub et bureau : offre une carte rétractable, une page dédiée dans le Hub et un widget pour le bureau.

## Installation

Dans `~/.config/mochi/plugins.toml`, ajoutez :

```toml
[plugins.chrono]
source = "path:plugins/chrono"
```

Compilez et activez le plugin :

```sh
mochi plugins install chrono
```

Dans `~/.config/mochi/config.toml`, ajoutez `"chrono"` à la liste des modules :

```toml
modules = [
    "idle",
    "osd",
    "workspaces",
    "hub",
    "chrono"
]
```

Rechargez le daemon :

```sh
mochi reload
```

## Commandes IPC

Toutes les actions sont accessibles via la ligne de commande `mochi ipc chrono` :

```sh
# État global
mochi ipc chrono status

# Basculer l'affichage (clock, stopwatch, timer)
mochi ipc chrono mode timer

# Minuteur
mochi ipc chrono timer_start 10        # Démarre un minuteur de 10 minutes
mochi ipc chrono timer_pause           # Met en pause ou reprend
mochi ipc chrono timer_add 5           # Ajoute 5 minutes
mochi ipc chrono timer_stop            # Arrête le minuteur

# Chronomètre
mochi ipc chrono stopwatch_start       # Démarre le chronomètre
mochi ipc chrono stopwatch_lap         # Enregistre un tour
mochi ipc chrono stopwatch_pause       # Pause ou reprise
mochi ipc chrono stopwatch_reset       # Remet à zéro
```

## Configuration

Dans `~/.config/mochi/config.toml` :

```toml
[module.chrono]
# Durée par défaut du minuteur (en minutes)
default_timer_minutes = 5

# Format de l'heure
clock_format = "%H:%M:%S"

# Emplacement de la bulle près de l'îlot (CenterRight, CenterLeft, Right, Left)
area = "CenterRight"

# Afficher la bulle pour le minuteur ou le chronomètre
timer_bubble = true
stopwatch_bubble = true

# Sonnerie de fin de minuteur
sound = true
```
