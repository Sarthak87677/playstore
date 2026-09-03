extends Node
## Local-only diagnostic log. Writes to user://veilforge.log.
## Nothing here ever leaves the machine: no sockets, no HTTP, no telemetry.

const MAX_LINES := 4000
const PATH := "user://veilforge.log"

var _lines: PackedStringArray = []
var _file: FileAccess = null
var enabled := true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_file = FileAccess.open(PATH, FileAccess.WRITE)
	info("=== VEILFORGE session start %s ===" % Time.get_datetime_string_from_system())
	info("Engine %s | %s | %s" % [
		Engine.get_version_info().string,
		OS.get_name(),
		RenderingServer.get_video_adapter_name()])

func _write(level: String, msg: String) -> void:
	if not enabled:
		return
	var line := "[%s] %s: %s" % [
		Time.get_time_string_from_system(), level, msg]
	_lines.append(line)
	if _lines.size() > MAX_LINES:
		_lines.remove_at(0)
	if _file:
		_file.store_line(line)
		_file.flush()

func info(msg: String) -> void:
	_write("INFO", msg)

func warn(msg: String) -> void:
	_write("WARN", msg)
	push_warning(msg)

func err(msg: String) -> void:
	_write("ERR ", msg)
	push_error(msg)

func dbg(msg: String) -> void:
	if OS.is_debug_build():
		_write("DBG ", msg)

func tail(n: int = 40) -> PackedStringArray:
	var start := maxi(0, _lines.size() - n)
	return _lines.slice(start)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if _file:
			_file.flush()
