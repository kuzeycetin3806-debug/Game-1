class_name UiFonts
extends RefCounted
## The web build has no system fonts, so symbols like ☀ ⚙ ✕ would show as boxes.
## A tiny DejaVu subset (assets/fonts/symbols.ttf) is added as a fallback.

const SYMBOLS_PATH: String = "res://assets/fonts/symbols.ttf"


static func install_symbol_fallback(font: Font) -> bool:
	var sym: Font = load(SYMBOLS_PATH)
	if font == null or sym == null:
		return false
	var fb: Array[Font] = font.fallbacks
	if fb.has(sym):
		return false
	fb.append(sym)
	font.fallbacks = fb
	return true
