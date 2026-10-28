class_name SimRng
extends RefCounted
## Deterministic, platform-independent RNG using only 32-bit integer math.
## GDScript ints are 64-bit; every intermediate stays below 2^63 so nothing
## depends on overflow behaviour.

const MASK32: int = 0xFFFFFFFF
const GOLDEN: int = 0x9E3779B9

var _state: int = 0


func _init(seed_value: int = 0) -> void:
	_state = seed_value & MASK32


## Seed for one (tick, stream) pair, independent of call order across sessions.
static func derive(city_seed: int, tick: int, stream: int) -> int:
	var h: int = mix32(city_seed & MASK32)
	h = mix32(h ^ (tick & MASK32))
	h = mix32(h ^ ((tick >> 32) & MASK32))
	return mix32(h ^ (stream & MASK32))


static func for_tick(city_seed: int, tick: int, stream: int) -> SimRng:
	return SimRng.new(derive(city_seed, tick, stream))


## Exact (a * b) mod 2^32 without exceeding 48-bit intermediates.
static func mul32(a: int, b: int) -> int:
	a &= MASK32
	b &= MASK32
	var lo: int = a * (b & 0xFFFF)
	var hi: int = ((a * (b >> 16)) & 0xFFFF) << 16
	return (lo + hi) & MASK32


## murmur3 finalizer.
static func mix32(x: int) -> int:
	x &= MASK32
	x = mul32(x ^ (x >> 16), 0x85EBCA6B)
	x = mul32(x ^ (x >> 13), 0xC2B2AE35)
	return (x ^ (x >> 16)) & MASK32


## FNV-1a over a byte array, 32-bit.
static func hash_bytes(bytes: PackedByteArray) -> int:
	var h: int = 0x811C9DC5
	for b: int in bytes:
		h = mul32(h ^ b, 0x01000193)
	return h


func next_u32() -> int:
	_state = (_state + GOLDEN) & MASK32
	return mix32(_state)


## Uniform-ish integer in [lo, hi] (inclusive). Modulo bias is negligible for game ranges.
func range_int(lo: int, hi: int) -> int:
	if hi <= lo:
		return lo
	return lo + next_u32() % (hi - lo + 1)


func chance_permille(p: int) -> bool:
	return next_u32() % 1000 < p
