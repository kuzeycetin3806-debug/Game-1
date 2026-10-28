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


func test_build_cards_sorted_by_category_then_cost() -> void:
	var c: ContentDb = SimFixture.content()
	var ids: Array[String] = Hud.sorted_building_ids(c)
	assert_eq(ids.size(), c.buildings.size())
	assert_eq(ids[0], "house_small")
	for i: int in range(1, ids.size()):
		var a: BuildingDef = c.get_building(ids[i - 1])
		var b: BuildingDef = c.get_building(ids[i])
		var ca: int = Hud.CATEGORIES.find(a.category)
		var cb: int = Hud.CATEGORIES.find(b.category)
		assert_true(ca < cb or (ca == cb and a.cost <= b.cost))
