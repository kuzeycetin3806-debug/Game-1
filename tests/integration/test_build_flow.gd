extends GutTest
## Drives the real main scene: place, confirm, select, demolish.

var main: Node
var city: CityView
var controller: BuildController


func before_each() -> void:
	SimRunner.new_city(777)
	SimRunner.sim.state.money_cents = 1_000_000 * 100
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)
	await wait_frames(2)
	city = main.get_node("%City") as CityView
	controller = city.build_controller


func test_place_building_at_screen_centre() -> void:
	var target := Vector2i(26, 26)
	city.camera_rig.snap_to(city.renderer.cell_center(target), 200.0)
	var before: int = SimRunner.sim.state.buildings.size()
	controller.start_placing("cafe")
	await wait_frames(1)
	assert_eq(controller.mode, BuildController.Mode.PLACING)
	var r: Dictionary = controller.confirm_placement()
	assert_true(r.ok, r.error)
	assert_eq(SimRunner.sim.state.buildings.size(), before + 1)
	assert_eq(SimRunner.sim.grid.building_at(target), SimRunner.sim.state.buildings[-1].id)
	assert_eq(controller.mode, BuildController.Mode.IDLE)


func test_invalid_spot_is_rejected() -> void:
	var occupied: Vector2i = SimRunner.sim.state.buildings[0].cell
	city.camera_rig.snap_to(city.renderer.cell_center(occupied), 200.0)
	controller.start_placing("cafe")
	await wait_frames(1)
	var before: int = SimRunner.sim.state.buildings.size()
	var r: Dictionary = controller.confirm_placement()
	assert_false(r.ok)
	assert_eq(SimRunner.sim.state.buildings.size(), before)
	assert_eq(controller.mode, BuildController.Mode.PLACING, "stay in placement so the player can move")


func test_select_and_demolish() -> void:
	var b: BuildingInstance = SimRunner.sim.state.buildings[0]
	controller.select(b.id)
	assert_eq(controller.mode, BuildController.Mode.SELECTED)
	var money_before: int = SimRunner.sim.state.money_cents
	assert_true(controller.demolish_selected().ok)
	assert_null(SimRunner.sim.state.building_by_id(b.id))
	assert_gt(SimRunner.sim.state.money_cents, money_before)
	assert_eq(controller.mode, BuildController.Mode.IDLE)


func test_tap_on_building_selects_it() -> void:
	var b: BuildingInstance = SimRunner.sim.state.buildings[0]
	var world: Vector3 = city.renderer.cell_center(b.cell)
	city.camera_rig.snap_to(world, 200.0)
	var screen: Vector2 = city.camera_rig.camera.unproject_position(world)
	city.camera_rig.tapped.emit(screen)
	assert_eq(controller.selected_id, b.id)


func test_renderer_draws_every_building() -> void:
	await wait_frames(1)
	var mm: MultiMesh = (city.renderer.get("_buildings_mm") as MultiMeshInstance3D).multimesh
	assert_gte(mm.instance_count, SimRunner.sim.state.buildings.size() - 2, "parks have no boxes")
