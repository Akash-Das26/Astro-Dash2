class_name Enemy
extends EnemyBase
## The plain enemy: straight down at `speed`, exactly what EnemyBase does.
## It exists as its own type so wave data can name it and per-type tuning
## (hp, speed, points) never leaks into the base or the other variants.
