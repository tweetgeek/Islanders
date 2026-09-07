class_name TimeUtil
extends RefCounted

## Jedyne miejsce w kliencie, które czyta zegar systemowy.
static var server_time_offset: float = 0.0


static func now() -> float:
	return Time.get_unix_time_from_system() + server_time_offset


## Kalibruje zegar klienta do czasu serwera (unix UTC).
static func set_server_time(server_unix: float) -> void:
	server_time_offset = server_unix - Time.get_unix_time_from_system()


## Parsuje ISO 8601 ("2026-09-07T12:00:00Z", "...+02:00", "...12:00:00.123Z") do unix (UTC).
static func parse_iso8601(text: String) -> float:
	var s := text.strip_edges()
	var offset_seconds := 0
	if s.ends_with("Z"):
		s = s.substr(0, s.length() - 1)
	elif s.length() > 19:
		var re := RegEx.create_from_string("([+-])(\\d{2}):?(\\d{2})$")
		var m := re.search(s)
		if m:
			var sign := 1 if m.get_string(1) == "+" else -1
			offset_seconds = sign * (int(m.get_string(2)) * 3600 + int(m.get_string(3)) * 60)
			s = s.substr(0, m.get_start())
	var dot := s.find(".")
	if dot >= 0:
		s = s.substr(0, dot)
	return float(Time.get_unix_time_from_datetime_string(s) - offset_seconds)


static func to_iso8601(unix: float) -> String:
	return Time.get_datetime_string_from_unix_time(int(unix), false) + "Z"


## 950 -> "950", 1234 -> "1.2k", 1500000 -> "1.5M"
static func format_amount(value: float) -> String:
	var v := floorf(value)
	if v < 1000.0:
		return "%d" % int(v)
	if v < 1000000.0:
		return "%.1fk" % (v / 1000.0)
	return "%.1fM" % (v / 1000000.0)


static func format_countdown(seconds: float) -> String:
	var s := maxi(int(seconds), 0)
	@warning_ignore("integer_division")
	return "%02d:%02d" % [s / 60, s % 60]
