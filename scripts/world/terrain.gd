class_name Terrain
extends Node3D
## Addon-free geometry clipmap. LEVELS nested N x N grids, level L has spacing BASE*2^L,
## snapped to 2*spacing around the active camera. Shader: res://shaders/terrain.gdshader.

const N := 128                 # quads per side per level (must be divisible by 4)
const BASE_SPACING := 1.0
const LEVELS := 14             # outer extent: 64 * 2^13 m = 524 km

var _levels: Array[MeshInstance3D] = []
var _materials: Array[ShaderMaterial] = []
var _shader: Shader
var _focus := Vector3.ZERO


func _ready() -> void:
	_shader = load("res://shaders/terrain.gdshader")
	var mesh := _build_grid_mesh()
	for l in LEVELS:
		var mi := MeshInstance3D.new()
		mi.name = "Level%d" % l
		mi.mesh = mesh
		var mat := ShaderMaterial.new()
		mat.shader = _shader
		mat.set_shader_parameter("half_n", float(N / 2))
		mi.material_override = mat
		mi.extra_cull_margin = 16384.0
		mi.custom_aabb = AABB(Vector3(-600000, -20000, -600000), Vector3(1200000, 40000, 1200000))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.layers = 1
		add_child(mi)
		_levels.append(mi)
		_materials.append(mat)
	update_focus(Vector3.ZERO, true)


func _build_grid_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	var h := N / 2
	verts.resize((N + 1) * (N + 1))
	var k := 0
	for z in range(-h, h + 1):
		for x in range(-h, h + 1):
			verts[k] = Vector3(x, 0, z)
			k += 1
	idx.resize(N * N * 6)
	k = 0
	for z in N:
		for x in N:
			var i0 := z * (N + 1) + x
			var i1 := i0 + 1
			var i2 := i0 + (N + 1)
			var i3 := i2 + 1
			idx[k] = i0; idx[k + 1] = i1; idx[k + 2] = i2
			idx[k + 3] = i1; idx[k + 4] = i3; idx[k + 5] = i2
			k += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	m.custom_aabb = AABB(Vector3(-600000, -20000, -600000), Vector3(1200000, 40000, 1200000))
	return m


func update_focus(cam_pos: Vector3, force := false) -> void:
	if not force and cam_pos.distance_squared_to(_focus) < 0.25:
		return
	_focus = cam_pos
	var prev_center := Vector2.ZERO
	var prev_half := 0.0
	for l in LEVELS:
		var s := BASE_SPACING * pow(2.0, l)
		var snap := 2.0 * s
		var c := Vector2(floorf(cam_pos.x / snap) * snap, floorf(cam_pos.z / snap) * snap)
		var mat := _materials[l]
		mat.set_shader_parameter("spacing", s)
		mat.set_shader_parameter("level_center", c)
		mat.set_shader_parameter("inner_half_extent", prev_half)
		mat.set_shader_parameter("inner_center", prev_center)
		prev_center = c
		prev_half = s * N * 0.5


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		update_focus(cam.global_position)
