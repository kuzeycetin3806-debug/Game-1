class_name BenchmarkReport
extends RefCounted
## Pure helpers for the in-game performance test: frame statistics, the
## recommended quality and the shareable text report. Unit tested.

const TARGET_FPS: float = 55.0
const TARGET_LOW_FPS: float = 40.0


## Frame times in seconds -> {avg_fps, low1_fps, avg_ms, worst_ms}.
static func stats(frame_times: PackedFloat32Array) -> Dictionary:
	if frame_times.is_empty():
		return {"avg_fps": 0.0, "low1_fps": 0.0, "avg_ms": 0.0, "worst_ms": 0.0}
	var total: float = 0.0
	var sorted: Array = Array(frame_times)
	sorted.sort()
	for t: float in frame_times:
		total += t
	var avg: float = total / frame_times.size()
	# "1 % low": average of the slowest 1 % of frames (at least one frame).
	var n: int = maxi(frame_times.size() / 100, 1)
	var worst_sum: float = 0.0
	for i: int in n:
		worst_sum += float(sorted[sorted.size() - 1 - i])
	return {"avg_fps": 1.0 / maxf(avg, 0.0001), "low1_fps": 1.0 / maxf(worst_sum / n, 0.0001),
		"avg_ms": avg * 1000.0, "worst_ms": float(sorted[-1]) * 1000.0}


## Highest quality (2..0) whose overview run meets the targets; 0 when none does.
## `runs` = [{quality, view, avg_fps, low1_fps, ...}].
static func recommend(runs: Array) -> int:
	for q: int in [2, 1, 0]:
		var ok: bool = false
		for r: Variant in runs:
			var d: Dictionary = r
			if int(d.quality) == q and String(d.view) == "overview":
				ok = float(d.avg_fps) >= TARGET_FPS and float(d.low1_fps) >= TARGET_LOW_FPS
		if ok:
			return q
	return 0


static func text(device: Dictionary, runs: Array, recommended: int, quality_names: Array, view_names: Dictionary, title: String, rec_label: String) -> String:
	var lines: PackedStringArray = [title]
	lines.append("%s · %s · %s" % [device.get("model", "?"), device.get("os", "?"), device.get("gpu", "?")])
	lines.append("CPU %s · %d çekirdek · ekran %s · %d bina" % [device.get("cpu", "?"), int(device.get("cores", 0)), device.get("screen", "?"), int(device.get("buildings", 0))])
	for r: Variant in runs:
		var d: Dictionary = r
		lines.append("%s / %s: %.0f FPS (%%1 düşük %.0f) · %.1f ms · %d çağrı · %dk üçgen" % [
			quality_names[int(d.quality)], view_names.get(String(d.view), d.view), float(d.avg_fps), float(d.low1_fps),
			float(d.avg_ms), int(d.draw_calls), int(d.primitives) / 1000])
	lines.append("%s: %s" % [rec_label, quality_names[recommended]])
	return "\n".join(lines)
