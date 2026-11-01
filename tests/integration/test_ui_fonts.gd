extends GutTest
## Symbols used by the UI must render without system fonts (web build).


func test_symbol_font_covers_every_ui_symbol() -> void:
	var sym: Font = load(UiFonts.SYMBOLS_PATH)
	assert_not_null(sym)
	for c: String in ["☀", "☁", "☂", "⚡", "≋", "❄", "⚙", "✕", "✓", "→", "•", "‹", "›", "…", "—"]:
		assert_true(sym.has_char(c.unicode_at(0)), "missing glyph %s" % c)


func test_install_is_idempotent() -> void:
	var f := FontVariation.new()
	assert_true(UiFonts.install_symbol_fallback(f))
	assert_false(UiFonts.install_symbol_fallback(f))
	assert_eq(f.fallbacks.size(), 1)
