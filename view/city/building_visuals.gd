class_name BuildingVisuals
extends RefCounted
## Pure mapping from a sim building to drawable pieces. Variation comes from
## the building id, so a building looks the same in every session.

const CELL: float = 8.0
const LOT_INSET: float = 2.2
const STYLE_CONSTRUCTION: float = 3.0
const LEAVES: Array[Color] = [
	Color("#7fae6a"), Color("#93bb6f"), Color("#6c9e64"), Color("#a7c47a"), Color("#e0a35e"),
]

## Output buckets:
## boxes:  {xform: Transform3D, color: Color, custom: Color} for building.gdshader
## plates: Transform3D (paving under lots and park paths)
## trees:  {pos: Vector3, scale: float, color: Color, conifer: bool}
static func build(b: BuildingInstance, def: BuildingDef, tick: int, origin_center: Vector3) -> Dictionary:
	var out: Dictionary = {"boxes": [], "plates": [], "trees": []}
	var span: float = def.size * CELL
	var center: Vector3 = origin_center + Vector3((def.size - 1) * CELL * 0.5, 0.0, (def.size - 1) * CELL * 0.5)
	var h: int = SimRng.mix32(b.id * 2654435761)
	var vis: Dictionary = def.visual
	var kind: String = String(vis.get("kind", "building"))
	var progress: float = construction_progress(b, tick)

	if kind == "park":
		(out.plates as Array).append(Transform3D(Basis.IDENTITY.scaled(Vector3(span - 1.0, 0.1, 2.4)), center + Vector3(0, 0.05, 0)))
		(out.plates as Array).append(Transform3D(Basis.IDENTITY.scaled(Vector3(2.4, 0.1, span - 1.0)), center + Vector3(0, 0.05, 0)))
		var rng := SimRng.new(h)
		var count: int = int(roundf(float(vis.get("trees", 4)) * (0.35 + 0.65 * progress)))
		var placed: int = 0
		var tries: int = 0
		while placed < count and tries < count * 6:
			tries += 1
			var lx: float = (rng.range_int(0, 1000) / 1000.0 - 0.5) * (span - 3.0)
			var lz: float = (rng.range_int(0, 1000) / 1000.0 - 0.5) * (span - 3.0)
			if absf(lx) < 1.8 or absf(lz) < 1.8:
				continue # keep the cross path clear
			(out.trees as Array).append({
				"pos": center + Vector3(lx, 0, lz),
				"scale": 0.75 + rng.range_int(0, 600) / 1000.0,
				"color": LEAVES[rng.range_int(0, LEAVES.size() - 1)],
				"conifer": rng.chance_permille(300),
			})
			placed += 1
		return out

	(out.plates as Array).append(Transform3D(Basis.IDENTITY.scaled(Vector3(span - 0.6, 0.25, span - 0.6)), center + Vector3(0, 0.125, 0)))
	var footprint: float = span - LOT_INSET
	var w: float = footprint * (0.86 + (h & 0xFF) / 255.0 * 0.14)
	var d: float = footprint * (0.86 + ((h >> 8) & 0xFF) / 255.0 * 0.14)
	var full_h: float = float(vis.get("height", 10.0)) * (0.9 + ((h >> 16) & 0xFF) / 255.0 * 0.2)
	var base_color: Color = Color.html(String(vis.get("color", "#e8e0d0")))
	var color: Color = base_color.lightened(((h >> 24) & 0x7F) / 127.0 * 0.08)
	var style: float = float(vis.get("style", 1))
	var garden: float = 1.0 if bool(vis.get("garden", false)) else 0.0
	var seed_v: float = (h & 0xFFFF) / 65535.0
	var base_y: float = 0.25

	if progress < 1.0:
		var ch: float = maxf(2.5, full_h * (0.15 + 0.85 * progress))
		(out.boxes as Array).append(_box(center + Vector3(0, base_y, 0), Vector3(w, ch, d), Color("#d9d2c4"), Color(seed_v, STYLE_CONSTRUCTION, 0, 0)))
		return out

	(out.boxes as Array).append(_box(center + Vector3(0, base_y, 0), Vector3(w, full_h, d), color, Color(seed_v, style, garden, 0)))
	if style >= 2.0 and full_h > 40.0:
		# Setback crown keeps towers from reading as plain boxes.
		var ch2: float = full_h * 0.22
		(out.boxes as Array).append(_box(center + Vector3(0, base_y + full_h, 0), Vector3(w * 0.68, ch2, d * 0.68), color.lightened(0.06), Color(seed_v + 0.5, style, 0, 0)))
	elif style >= 1.0 and full_h > 6.0 and (h & 3) == 0:
		(out.boxes as Array).append(_box(center + Vector3(w * 0.15, base_y + full_h, -d * 0.1), Vector3(w * 0.35, 2.4, d * 0.3), color.darkened(0.05), Color(seed_v, 0, 0, 0)))
	return out


static func construction_progress(b: BuildingInstance, tick: int) -> float:
	if b.ready_tick <= b.placed_tick or tick >= b.ready_tick:
		return 1.0
	return clampf(float(tick - b.placed_tick) / float(b.ready_tick - b.placed_tick), 0.0, 1.0)


static func _box(base_center: Vector3, size: Vector3, color: Color, custom: Color) -> Dictionary:
	return {"xform": Transform3D(Basis.IDENTITY.scaled(size), base_center + Vector3(0, size.y * 0.5, 0)), "color": color, "custom": custom}
