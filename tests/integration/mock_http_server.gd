class_name MockHttpServer
extends Node
## Tiny HTTP/1.1 server for tests: answers every request with a canned
## response (or never, to test timeouts) and records what it received.

var status: int = 200
var body: String = "{}"
var silent: bool = false
var requests: Array[Dictionary] = [] # {path, headers, body}

var _server := TCPServer.new()
var _peers: Array[StreamPeerTCP] = []
var _buffers: Dictionary = {} # peer -> PackedByteArray


func start(port: int) -> Error:
	return _server.listen(port, "127.0.0.1")


func _exit_tree() -> void:
	_server.stop()


func _process(_delta: float) -> void:
	while _server.is_connection_available():
		var p: StreamPeerTCP = _server.take_connection()
		_peers.append(p)
		_buffers[p] = PackedByteArray()
	for p: StreamPeerTCP in _peers.duplicate():
		p.poll()
		if p.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_peers.erase(p)
			continue
		var n: int = p.get_available_bytes()
		if n > 0:
			_buffers[p] = (_buffers[p] as PackedByteArray) + p.get_data(n)[1]
		var req: Dictionary = _parse(_buffers[p] as PackedByteArray)
		if req.is_empty():
			continue
		requests.append(req)
		_buffers[p] = PackedByteArray()
		if silent:
			continue
		var payload: PackedByteArray = body.to_utf8_buffer()
		var head: String = "HTTP/1.1 %d X\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % [status, payload.size()]
		p.put_data(head.to_utf8_buffer() + payload)
		p.disconnect_from_host()
		_peers.erase(p)


## Complete request (headers + Content-Length body) or {}.
static func _parse(buf: PackedByteArray) -> Dictionary:
	var text: String = buf.get_string_from_utf8()
	var split: int = text.find("\r\n\r\n")
	if split < 0:
		return {}
	var head: PackedStringArray = text.substr(0, split).split("\r\n")
	var headers: Dictionary = {}
	for line: String in head.slice(1):
		var i: int = line.find(":")
		if i > 0:
			headers[line.substr(0, i).strip_edges().to_lower()] = line.substr(i + 1).strip_edges()
	var length: int = int(headers.get("content-length", "0"))
	var body_bytes: PackedByteArray = buf.slice(text.substr(0, split + 4).to_utf8_buffer().size())
	if body_bytes.size() < length:
		return {}
	return {"path": head[0].get_slice(" ", 1), "headers": headers, "body": body_bytes.slice(0, length).get_string_from_utf8()}
