extends Node
class_name PowerNet
## Directed power graph. Sources push charge along links; a link only conducts
## when its condition holds - typically "this section is in Memory state" or
## "this conduit has been imprinted CONDUCTIVE". Sinks fire when energised.
##
## This is the backbone of the routing puzzles in Nacre City, the Observatory
## and the Convergence Core.

signal network_changed()

class Link:
	var a: String
	var b: String
	var cond: Callable
	var bidirectional: bool
	var visual: Node3D
	func conducts() -> bool:
		return cond.is_valid() and bool(cond.call())

var points: Dictionary = {}         # id -> PowerPoint
var links: Array = []
var _powered: Dictionary = {}
var _dirty := true

func register(p) -> void:
	points[p.point_id] = p
	_dirty = true

func link(a: String, b: String, cond: Callable, bidirectional: bool = true,
		visual: Node3D = null) -> Link:
	var l := Link.new()
	l.a = a
	l.b = b
	l.cond = cond
	l.bidirectional = bidirectional
	l.visual = visual
	links.append(l)
	_dirty = true
	return l

func mark_dirty() -> void:
	_dirty = true

func is_powered(id: String) -> bool:
	return bool(_powered.get(id, false))

func _process(_dt: float) -> void:
	if not _dirty:
		# Cheap watch: any link whose conduction changed re-triggers a solve.
		for l in links:
			var key := "%s>%s" % [l.a, l.b]
			var now: bool = l.conducts()
			if bool(_link_cache.get(key, false)) != now:
				_dirty = true
				break
	if _dirty:
		_dirty = false
		solve()

var _link_cache: Dictionary = {}

func solve() -> void:
	_link_cache.clear()
	var adj: Dictionary = {}
	for l in links:
		var key := "%s>%s" % [l.a, l.b]
		var c: bool = l.conducts()
		_link_cache[key] = c
		if l.visual and l.visual.has_method("set_conducting"):
			l.visual.set_conducting(c)
		if not c:
			continue
		if not adj.has(l.a): adj[l.a] = []
		adj[l.a].append(l.b)
		if l.bidirectional:
			if not adj.has(l.b): adj[l.b] = []
			adj[l.b].append(l.a)

	var new_powered: Dictionary = {}
	var queue: Array = []
	for id in points.keys():
		var p = points[id]
		if p.is_source and p.enabled:
			queue.append(id)
			new_powered[id] = true
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		for nxt in adj.get(cur, []):
			if new_powered.has(nxt):
				continue
			var np = points.get(nxt, null)
			if np != null and not np.enabled:
				continue
			new_powered[nxt] = true
			queue.append(nxt)

	var changed := false
	for id in points.keys():
		var was := bool(_powered.get(id, false))
		var now := bool(new_powered.get(id, false))
		if was != now:
			changed = true
			points[id].set_powered(now)
	_powered = new_powered
	if changed:
		network_changed.emit()

func powered_count() -> int:
	var n := 0
	for id in _powered.keys():
		if bool(_powered[id]):
			n += 1
	return n
