class_name HttpProvider
extends ApiProvider

## Szkielet pod NestJS. HTTPRequest musi być w drzewie, więc provider dostaje węzeł-gospodarza.
var base_url: String
var _host: Node


func _init(host: Node, url: String) -> void:
	_host = host
	base_url = url.rstrip("/")


func _request_json(path: String) -> Variant:
	var req := HTTPRequest.new()
	_host.add_child(req)
	var err := req.request(base_url + path)
	if err != OK:
		req.queue_free()
		push_error("HttpProvider: request %s nieudany (%d)" % [path, err])
		return null
	var result: Array = await req.request_completed
	req.queue_free()
	if result[0] != HTTPRequest.RESULT_SUCCESS or result[1] != 200:
		push_error("HttpProvider: %s -> result %d, status %d" % [path, result[0], result[1]])
		return null
	return JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())


func fetch_world() -> Dictionary:
	var d: Variant = await _request_json("/world")
	return d if d is Dictionary else {}


func fetch_settlements() -> Array:
	var a: Variant = await _request_json("/settlements")
	return a if a is Array else []


func fetch_fleets() -> Array:
	var a: Variant = await _request_json("/fleets")
	return a if a is Array else []
