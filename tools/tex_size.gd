extends SceneTree
## Prints a texture's file size, its opaque bounds and the fraction of the file
## the art actually covers, for sizing padded pack art.

func _initialize() -> void:
	var paths: Array[String] = [
		"res://assets/sprites/spacepixels-0.2.0/spacepixels-0.2.0/pixel_ship3_red.png",
		"res://assets/sprites/spacepixels-0.2.0/spacepixels-0.2.0/pixel_ship3_green.png",
		"res://assets/sprites/spacepixels-0.2.0/spacepixels-0.2.0/pixel_ship3_yellow.png",
		"res://assets/sprites/spacepixels-0.2.0/spacepixels-0.2.0/pixel_shape3_blue.png",
		"res://assets/sprites/spacepixels-0.2.0/spacepixels-0.2.0/pixel_ship_blue_small.png",
		"res://assets/sprites/spacepixels-0.2.0/spacepixels-0.2.0/pixel_ship_red_small_2.png",
		"res://assets/sprites/spacepixels_ships_stroked/space_pixels_ships_stroked/ship_red_stroked.png",
	]
	for path: String in paths:
		var texture: Texture2D = load(path) as Texture2D
		if texture == null:
			print("MISSING %s" % path)
			continue
		var image: Image = texture.get_image()
		if image == null:
			print("NO IMAGE %s" % path)
			continue
		var used: Rect2 = image.get_used_rect()
		print("TEX %s file=%dx%d used=%dx%d at (%d,%d)" % [
			path.get_file(), texture.get_width(), texture.get_height(),
			int(used.size.x), int(used.size.y), int(used.position.x), int(used.position.y),
		])
	quit(0)
