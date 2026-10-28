class_name SimConfig
extends RefCounted
## Structural constants of the simulation. Balance numbers live in data/balance/.

const TICK_SECONDS: int = 600 # VARSAYIM: 1 tick = 10 real minutes
const TICKS_PER_DAY: int = 86400 / TICK_SECONDS
const SECONDS_PER_DAY: int = 86400
## Happiness, traffic, pollution etc. are stored as permille (0..1000).
const PERMILLE: int = 1000
## Money is stored in kuruş (1/100 lira) so per-tick income never rounds to zero.
const CENTS: int = 100
