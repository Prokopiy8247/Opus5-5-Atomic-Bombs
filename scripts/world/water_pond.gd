class_name WaterPond
extends Node3D
## Local lagoon for the underwater burst (Baker): a disc of water a few km across around the
## target, with an outgoing ring wave train driven by the explosion age (global g_blast_age).

const SHADER := preload("res://shaders/water.gdshader")

var mesh_inst: MeshInstance3D
var radius := 4000.0


func setup(gz: Vector3, r: float) -> void:
	radius = r
	var level := gz.y + 0.6
	global_position = Vector3(gz.x, level, gz.z)
	RenderingServer.global_shader_parameter_set("g_water", Vector4(gz.x, gz.z, r, level))
	mesh_inst = MeshInstance3D.new()
	mesh_inst.mesh = _disc_mesh(r * 1.02, 160, 256)
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("pond_radius", r)
	mesh_inst.material_override = mat
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_inst.extra_cull_margin = 5000.0
	add_child(mesh_inst)


## Polar disc with denser rings near the centre (where the waves are tall).
func _disc_mesh(r: float, rings: int, segs: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	verts.append(Vector3.ZERO)
	for i in range(1, rings + 1):
		var f := float(i) / rings
		var rr := r * f * f * 0.85 + r * f * 0.15
		for s in segs:
			var a := TAU * s / segs
			verts.append(Vector3(cos(a) * rr, 0.0, sin(a) * rr))
	for s in segs:
		idx.append_array([0, 1 + (s + 1) % segs, 1 + s])
	for i in range(1, rings):
		var b0 := 1 + (i - 1) * segs
		var b1 := 1 + i * segs
		for s in segs:
			var s1 := (s + 1) % segs
			idx.append_array([b0 + s, b0 + s1, b1 + s])
			idx.append_array([b0 + s1, b1 + s1, b1 + s])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m
