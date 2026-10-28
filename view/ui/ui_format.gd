class_name UiFormat
extends RefCounted
## Turkish-style number formatting for the HUD.


## 1234567 -> "1.234.567"
static func thousands(n: int) -> String:
	var neg: bool = n < 0
	var digits: String = str(absi(n))
	var out: String = ""
	var count: int = 0
	for i: int in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return ("-" if neg else "") + out


static func money(lira: int) -> String:
	return "%s TL" % thousands(lira)


## Turkish puts the percent sign first: %62.
static func percent(permille: int) -> String:
	return "%%%d" % roundi(permille / 10.0)
