class_name LetterWriter
extends RefCounted
## Writes a citizen's letter from templates (data/text_templates/letters_<lang>.json).
## Deterministic per letter id. The backend (M5) can replace subject/body; the
## reply options always come from the data so gameplay never depends on AI text.

const FORMAL_AGE: int = 50

var templates: Dictionary
var fallback: Dictionary
var translate: Callable


static func create(p_templates: Dictionary, p_fallback: Dictionary, p_translate: Callable) -> LetterWriter:
	var w := LetterWriter.new()
	w.templates = p_templates
	w.fallback = p_fallback
	w.translate = p_translate
	return w


## `citizen` is Citizen.to_dict(); `options` the topic's option list from content.
func render(letter: Dictionary, citizen: Dictionary, options: Array) -> Dictionary:
	var id: int = int(letter.id)
	var topic: String = String(letter.topic)
	var t: Dictionary = _topic(topic)
	var vars: Dictionary = base_vars(letter, citizen)
	var formal: bool = int(citizen.get("age", 30)) >= FORMAL_AGE
	var greetings: Dictionary = _value("greeting", {}) as Dictionary
	var signoffs: Dictionary = _value("signoff", {}) as Dictionary
	var opt_labels: Dictionary = _value("options", {}) as Dictionary
	var opts: Array = []
	for o: Variant in options:
		var oid: String = String((o as Dictionary).id)
		opts.append({"id": oid, "label": String(opt_labels.get(oid, (fallback.get("options", {}) as Dictionary).get(oid, oid)))})
	var status_line: String = ""
	match String(letter.get("status", "open")):
		"answered":
			var label: String = String(opt_labels.get(String(letter.reply), letter.reply))
			status_line = TemplateWriter.fill(String(_value("you_replied", "{reply}")), {"reply": label})
		"expired":
			status_line = String(_value("expired", ""))
	return {
		"id": id,
		"subject": TemplateWriter.fill(_pick(t.get("subject", [topic]) as Array, id, "s"), vars),
		"greeting": _pick(greetings.get("formal" if formal else "casual", [""]) as Array, id, "g"),
		"body": TemplateWriter.fill(_pick(t.get("body", [""]) as Array, id, "b"), vars),
		"memory_line": memory_line(letter.get("memory", {}) as Dictionary, id, vars),
		"signoff": _pick(signoffs.get(String(letter.get("tone", "request")), [""]) as Array, id, "o"),
		"signature": TemplateWriter.fill(String(_value("signature", "{name}")), vars),
		"options": opts,
		"status_line": status_line,
	}


func base_vars(letter: Dictionary, citizen: Dictionary) -> Dictionary:
	return {
		"name": "%s %s" % [citizen.get("first", ""), citizen.get("last", "")],
		"first": String(citizen.get("first", "")),
		"district": String(letter.get("district", "")),
		"occupation": String(translate.call(String(citizen.get("occupation", "")))),
	}


## One sentence recalling the citizen's strongest memory, or "".
func memory_line(m: Dictionary, id: int, vars: Dictionary) -> String:
	if m.is_empty():
		return ""
	var by_kind: Dictionary = (_value("memory", {}) as Dictionary).get(String(m.kind), {})
	var lines: Array = by_kind.get("pos" if int(m.valence) >= 0 else "neg", [])
	if lines.is_empty():
		return ""
	var v: Dictionary = vars.duplicate()
	var ref: String = String(m.get("ref", ""))
	v.policy = String(translate.call("POL_" + ref.to_upper()))
	v.building = String(translate.call("BLD_" + ref.to_upper()))
	return TemplateWriter.fill(_pick(lines, id, "m"), v)


func _pick(options: Array, id: int, salt: String) -> String:
	if options.is_empty():
		return ""
	return String(options[SimRng.mix32(id * 7919 ^ SimRng.hash_bytes(salt.to_utf8_buffer())) % options.size()])


func _topic(id: String) -> Dictionary:
	var own: Dictionary = templates.get("topics", {})
	if own.has(id):
		return own[id]
	return (fallback.get("topics", {}) as Dictionary).get(id, {})


func _value(key: String, default_value: Variant) -> Variant:
	if templates.has(key):
		return templates[key]
	return fallback.get(key, default_value)
