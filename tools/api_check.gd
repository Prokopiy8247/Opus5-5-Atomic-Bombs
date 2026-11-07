extends SceneTree
## Verifies that engine APIs used by the project exist in this Godot build.
## Run: godot --headless --path . -s res://tools/api_check.gd

func _init() -> void:
	var checks := {
		"Environment": ["tonemap_mode", "glow_enabled", "glow_hdr_threshold", "fog_enabled", "fog_aerial_perspective", "fog_height", "fog_height_density", "fog_sky_affect", "fog_depth_begin", "fog_mode", "adjustment_enabled", "volumetric_fog_enabled", "sdfgi_enabled", "ssao_enabled", "tonemap_white", "tonemap_exposure", "glow_bloom", "glow_blend_mode", "glow_map"],
		"CameraAttributesPractical": ["auto_exposure_enabled", "auto_exposure_min_sensitivity", "auto_exposure_max_sensitivity", "exposure_multiplier", "exposure_sensitivity", "dof_blur_far_enabled"],
		"Camera3D": ["near", "far", "fov", "attributes", "compositor"],
		"GPUParticlesCollisionHeightField3D": ["size", "resolution", "follow_camera_enabled"],
		"GPUParticles3D": ["visibility_aabb", "amount_ratio", "fixed_fps", "trail_enabled"],
		"AudioStreamWAV": ["data", "format", "mix_rate", "stereo", "loop_mode"],
		"AudioEffectHardLimiter": ["ceiling_db"],
		"AudioEffectLowPassFilter": ["cutoff_hz"],
		"AudioEffectReverb": ["room_size"],
		"OmniLight3D": ["omni_range", "omni_attenuation"],
		"DirectionalLight3D": ["directional_shadow_max_distance", "sky_mode"],
		"Light3D": ["light_energy", "light_cull_mask", "light_intensity_lumens", "shadow_enabled"],
		"GeometryInstance3D": ["extra_cull_margin", "custom_aabb", "cast_shadow"],
		"Viewport": ["use_hdr_2d", "msaa_3d", "screen_space_aa", "use_taa", "scaling_3d_mode", "scaling_3d_scale", "positional_shadow_atlas_size"],
		"MultiMesh": ["use_custom_data", "use_colors", "transform_format", "instance_count"],
		"NoiseTexture3D": ["noise", "seamless", "width", "height", "depth"],
		"FastNoiseLite": ["noise_type", "fractal_type"],
		"WorldEnvironment": ["environment", "camera_attributes"],
		"ShaderMaterial": ["shader"],
		"SubViewport": ["size", "own_world_3d", "transparent_bg"],
		"Compositor": ["compositor_effects"],
		"SystemFont": ["font_names"],
		"ImageTexture3D": [],
		"MovieWriter": [],
	}
	var ok := true
	for cls in checks:
		if not ClassDB.class_exists(cls):
			print("MISSING CLASS ", cls)
			ok = false
			continue
		for prop in checks[cls]:
			var found := false
			for p in ClassDB.class_get_property_list(cls, false):
				if p["name"] == prop:
					found = true
					break
			if not found:
				print("MISSING PROP ", cls, ".", prop)
				ok = false
	# enum values of interest
	print("TONE_MAPPER_AGX=", Environment.TONE_MAPPER_AGX if "TONE_MAPPER_AGX" in Environment else -1)
	print("Engine version: ", Engine.get_version_info())
	var rs_methods := ["global_shader_parameter_add", "global_shader_parameter_set", "frame_post_draw"]
	for m in ["global_shader_parameter_add", "global_shader_parameter_set"]:
		if not ClassDB.class_has_method("RenderingServer", m):
			print("MISSING METHOD RenderingServer.", m)
			ok = false
	for m in ["blit_rect", "save_png", "resize", "create_empty"]:
		if not ClassDB.class_has_method("Image", m):
			print("MISSING METHOD Image.", m)
			ok = false
	print("API_CHECK ", "OK" if ok else "HAS_MISSING")
	quit()
