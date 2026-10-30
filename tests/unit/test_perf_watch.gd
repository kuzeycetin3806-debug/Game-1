extends GutTest


func test_decide() -> void:
	assert_eq(PerfWatch.decide(30.0, 2), 1)
	assert_eq(PerfWatch.decide(30.0, 0), -1, "already lowest")
	assert_eq(PerfWatch.decide(58.0, 2), -1)
