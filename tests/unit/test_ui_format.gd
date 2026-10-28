extends GutTest


func test_thousands() -> void:
	assert_eq(UiFormat.thousands(0), "0")
	assert_eq(UiFormat.thousands(999), "999")
	assert_eq(UiFormat.thousands(1000), "1.000")
	assert_eq(UiFormat.thousands(1234567), "1.234.567")
	assert_eq(UiFormat.thousands(-45000), "-45.000")


func test_percent_turkish_order() -> void:
	assert_eq(UiFormat.percent(623), "%62")
	assert_eq(UiFormat.percent(1000), "%100")


func test_money() -> void:
	assert_eq(UiFormat.money(250000), "250.000 TL")
