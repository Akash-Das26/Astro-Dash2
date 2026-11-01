# Balance report

**Date:** 2026-11-02. **Harness:** `tests/battle_bot.gd`, run with
`res://tests/battle_bot.tscn -- <difficulty> <band>` on Godot 4.7.2, headless.

Each row flies a real campaign battle for 60 s of game time at
`Engine.time_scale = 4` (about 15 s of wall time): pulse laser + heavy cannon,
no purchased upgrades, 500 banked energy, shield mode AUTO, a fresh seeded
galaxy per run. The bot aims at the nearest fighter, holds `shoot` /
`shoot_alt`, strafes at close range and makes two long runs across the arena so
the wrap is exercised. Balance rows fly the requested distance band (band 1 =
nearest, 4 = the red expanse); `citadel` and `gate` rows fly that station body.

No tuning value was changed for this run; this is a measurement only.

## Wins and hull left

Average hull is the mean of `hp / max_hp` at the end of the run, so a loss
counts as 0%.

| Difficulty | Band | Runs | Wins | Avg hull left | Seeds |
| --- | --- | --- | --- | --- | --- |
| cadet | 1 | 3 | 2 | 31% | 60721, 60737, 60754 |
| cadet | 2 | 3 | 0 | 0% | 60770, 60787, 60803 |
| cadet | 3 | 3 | 1 | 6% | 60819, 60836, 60852 |
| cadet | 4 | 3 | 2 | 36% | 60868, 60885, 60901 |
| vector | 1 | 3 | 2 | 21% | 60918, 60934, 60950 |
| vector | 2 | 3 | 0 | 0% | 60967, 60983, 61000 |
| vector | 3 | 3 | 1 | 22% | 61016, 61032, 61049 |
| vector | 4 | 3 | 0 | 0% | 61065, 61081, 61098 |
| supernova | 1 | 3 | 0 | 0% | 1067582951, 1042898961, 2143251766 |
| supernova | 2 | 3 | 0 | 0% | 1283800712, 2213583637, 3882853891 |
| supernova | 3 | 3 | 1 | 17% | 3420049708, 61229, 234235715 |
| supernova | 4 | 3 | 0 | 0% | 2617734532, 4145126590, 1564525838 |
| event_horizon | 1 | 3 | 0 | 0% | 39718688, 349753739, 1705367722 |
| event_horizon | 2 | 3 | 1 | 18% | 1236500873, 2982978887, 61392 |
| event_horizon | 3 | 3 | 1 | 5% | 3753876466, 61425, 1009158341 |
| event_horizon | 4 | 3 | 0 | 0% | 36255165, 1919329206, 3663574992 |
| singularity | 1 | 3 | 0 | 0% | 3961227108, 4200200282, 2478814489 |
| singularity | 2 | 3 | 0 | 0% | 3016301519, 3138035587, 1461634295 |
| singularity | 3 | 3 | 0 | 0% | 1508458032, 1896952213, 2963023474 |
| singularity | 4 | 3 | 0 | 0% | 3637521650, 791585676, 3670188706 |
| vector | gate | 3 | 3 | 100% | 34770, 34788, 34805 |
| vector | citadel | 3 | 2 | 52% | 34719, 34736, 34753 |

**Station rows caveat:** the station only flies in after the director's last
escort wave, and the harness clears escorts to reach it. That clear also ends
the battle, so a station was on the field in only two rows of the whole sweep
(`vector` band 2 run 2 for 12 HP and `vector` citadel run 3 for 54 HP). The
other four station rows ended before it arrived and are wins against the escort
alone, which is why `gate` shows a 100% average hull. The gate rows therefore do
not measure the station and should not be read as boss balance.

## HP lost per attacker

Summed over all 66 rows, worst first. `contact` is hull-on-hull damage,
`asteroid` is rock impacts.

| Enemy kind | HP removed |
| --- | --- |
| gunner | 1334 |
| asteroid | 1137 |
| scout | 972 |
| elite_red | 819 |
| heavy | 509 |
| drone | 316 |
| elite_green | 263 |
| elite_yellow | 222 |
| boss | 66 |
| contact | 40 |

## What the sweep covers

- Elites are present and dangerous from band 2 up: `elite_red` alone removes
  819 HP across the sweep, more than `heavy` (509).
- `drone` (316) and `elite_green` (263) show up from band 2/3 as designed.
- `elite_yellow` (222) is the mildest attacker, which fits a support unit.
- Every row wrapped at least twice and no row reported the ship outside the
  arena; node count never grew by more than 200 over a run except where a fight
  was still spawning (`+63` worst).

## Boss fights (stage 18)

`-- <difficulty> boss` starts a citadel battle, stops the escort waves and calls
the station in on the first frame, then flies 90 s of game time at 4x with pulse
laser + heavy cannon and no upgrades, three runs per mode. **Hull** is the ship's
HP when the row ended, **station** is the station's HP then, and **phases** split
the hull lost by thirds of the station's own health bar.

| Difficulty | Run | Hull left | Station left | Boss damage | Phase that hurt most |
| --- | --- | --- | --- | --- | --- |
| cadet | 1 | 0/100 | 58/184 | 50 | 66-33% (44) |
| cadet | 2 | 12/100 | 0/162 | 40 | 100-66% (56) |
| cadet | 3 | 58/100 | 0/155 | 30 | 100-66% (32) |
| vector | 1 | 0/100 | 122/248 | 30 | 100-66% (94) |
| vector | 2 | 1/100 | 0/275 | 84 | 100-66% (60) |
| vector | 3 | 13/100 | 0/158 | 72 | 100-66% (51) |
| supernova | 1 | 0/100 | 111/231 | 64 | 100-66% (78) |
| supernova | 2 | 0/100 | 69/198 | 82 | 100-66% (74) |
| supernova | 3 | 0/100 | 45/321 | 82 | 100-66% (74) |
| event_horizon | 1 | 0/100 | 62/278 | 79 | 100-66% (72) |
| event_horizon | 2 | 0/100 | 234/291 | 58 | 100-66% (100) |
| event_horizon | 3 | 0/100 | 54/264 | 100 | 100-66% (51) |
| singularity | 1 | 0/100 | 140/284 | 74 | 100-66% (86) |
| singularity | 2 | 0/100 | 464/560 | 74 | 100-66% (100) |
| singularity | 3 | 0/100 | 201/333 | 100 | 66-33% (60) |

**What the rows say**

- **4 of 15 killed the station** (both CADET runs that survived, two VECTOR
  runs); in the other 11 the ship died with the station still up, so the mode
  multiplier on station HP (184 CADET, 248 VECTOR, 198-321 SUPERNOVA,
  264-291 EVENT HORIZON, 284-560 SINGULARITY) is what turns this into a wall.
- **The station is the dominant threat.** In 13 of 15 rows the `boss` line is
  the largest source of hull lost; only the two CADET rows that killed it lost
  more to asteroids.
- **Damage is front-loaded.** 13 of 15 rows took their worst beating while the
  station was still above 66% HP, which is the window where the bot is closing
  in with the shield up and eating the first volleys; the last third rarely
  lands a hit because the ship is already dead or the station is nearly gone.
- Station HP never regenerates: the flat sections in the HP logs are the rows
  where the ship had already died and nothing was shooting any more.

No tuning value was changed; this is a measurement only.
