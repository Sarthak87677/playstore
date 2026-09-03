extends StaticBody3D
class_name Terrain
## Procedural heightfield terrain: an ArrayMesh with vertex-colour blending
## between two materials, plus a matching collision shape.
##
## Chapters describe their landscape by supplying a height function; this class
## turns it into geometry, collision, a surface tag for footsteps, and a
## sampler the props/vegetation use to sit on the ground.

var size: Vector2 = Vector2(200, 200)
var resolution: int = 96
var height_fn: Callable
var mesh_instance: MeshInstance3D
var _heights: PackedFloat32Array = PackedFloat32Array()
var _cols: int = 0
var _rows: int = 0
var _origin: Vector2 = Vector2.ZERO

func build(p_size: Vector2, p_res: int, p_height_fn: Callable,
		material: Material, surface: int = Veil.Surface.STONE) -> void:
	size = p_size
	resolution = maxi(4, p_res)
	height_fn = p_height_fn
	_cols = resolution + 1
	_rows = resolution + 1
	_origin = -size * 0.5
	_heights.resize(_cols * _rows)
	var step := size / float(resolution)
	if not is_equal_approx(step.x, step.y):
		Log.warn("Terrain cells are not square (%.3f x %.3f); collision assumes square cells."
			% [step.x, step.y])

	# Build the surface arrays directly. SurfaceTool is far too slow for a
	# 100k-triangle heightfield in GDScript, so vertices, normals, UVs and
	# indices are filled into packed arrays and handed to the mesh in one call.
	var vcount := _cols * _rows
	var verts := PackedVector3Array(); verts.resize(vcount)
	var norms := PackedVector3Array(); norms.resize(vcount)
	var uvs := PackedVector2Array(); uvs.resize(vcount)
	var idx := PackedInt32Array(); idx.resize(resolution * resolution * 6)

	for j in _rows:
		for i in _cols:
			var wx := _origin.x + step.x * i
			var wz := _origin.y + step.y * j
			_heights[j * _cols + i] = float(height_fn.call(wx, wz))

	for j in _rows:
		for i in _cols:
			var k := j * _cols + i
			var wx := _origin.x + step.x * i
			var wz := _origin.y + step.y * j
			verts[k] = Vector3(wx, _heights[k], wz)
			uvs[k] = Vector2(wx, wz) * 0.12
			# Central differences on the height grid give exact vertex normals.
			var hl := _heights[j * _cols + maxi(i - 1, 0)]
			var hr := _heights[j * _cols + mini(i + 1, _cols - 1)]
			var hd := _heights[maxi(j - 1, 0) * _cols + i]
			var hu := _heights[mini(j + 1, _rows - 1) * _cols + i]
			norms[k] = Vector3((hl - hr) * step.y * 2.0, 2.0 * step.x * step.y,
				(hd - hu) * step.x * 2.0).normalized()

	var w := 0
	for j in resolution:
		for i in resolution:
			var a := j * _cols + i
			var b := a + 1
			var c := a + _cols
			var d := c + 1
			idx[w] = a; idx[w + 1] = c; idx[w + 2] = d
			idx[w + 3] = a; idx[w + 4] = d; idx[w + 5] = b
			w += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = m
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mesh_instance)

	# HeightMapShape3D samples on a unit grid, so the shape has to be scaled onto
	# the world grid. Godot Physics only handles *uniform* scale reliably, so the
	# stored heights are pre-divided by the cell size and the shape is then
	# scaled uniformly: world Y comes back out exactly right.
	var shape := CollisionShape3D.new()
	var hf := HeightMapShape3D.new()
	var cell := step.x
	var scaled := PackedFloat32Array()
	scaled.resize(_heights.size())
	for i in _heights.size():
		scaled[i] = _heights[i] / cell
	hf.map_width = _cols
	hf.map_depth = _rows
	hf.map_data = scaled
	shape.shape = hf
	shape.scale = Vector3(cell, cell, cell)
	add_child(shape)

	collision_layer = Veil.L_WORLD
	collision_mask = 0
	set_meta("surface", surface)
	add_to_group("terrain")

## World-space height sampled with bilinear interpolation.
func height_at(x: float, z: float) -> float:
	if _cols == 0:
		return 0.0
	var step := size / float(resolution)
	var fx := (x - _origin.x) / step.x
	var fz := (z - _origin.y) / step.y
	var i := clampi(int(floor(fx)), 0, _cols - 2)
	var j := clampi(int(floor(fz)), 0, _rows - 2)
	var tx := clampf(fx - i, 0.0, 1.0)
	var tz := clampf(fz - j, 0.0, 1.0)
	var h00 := _heights[j * _cols + i]
	var h10 := _heights[j * _cols + i + 1]
	var h01 := _heights[(j + 1) * _cols + i]
	var h11 := _heights[(j + 1) * _cols + i + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)

func normal_at(x: float, z: float) -> Vector3:
	var e := 0.6
	var hl := height_at(x - e, z)
	var hr := height_at(x + e, z)
	var hd := height_at(x, z - e)
	var hu := height_at(x, z + e)
	return Vector3(hl - hr, 2.0 * e, hd - hu).normalized()

func slope_at(x: float, z: float) -> float:
	return rad_to_deg(acos(clampf(normal_at(x, z).dot(Vector3.UP), -1.0, 1.0)))
