extends TextureRect
const Icons = preload("c4_icon_cache43.gd")

func _init() -> void:
	custom_minimum_size = Vector2(140, 76)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func bind(remote: bool) -> void:
	texture = Icons.texture_for(remote)
