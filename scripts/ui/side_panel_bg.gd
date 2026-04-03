extends PanelContainer

const SIDE_PANEL_WIDTH := 200

@export var default_tex_path: String = ""
@export var db_key: String = ""

var _tex: Texture2D = null

func _ready() -> void:
	_load_texture()
	# Ensure panels using this script default to the shared width when unspecified
	if custom_minimum_size.x == 0:
		custom_minimum_size.x = SIDE_PANEL_WIDTH
	queue_redraw()

func _load_texture() -> void:
	var path := default_tex_path
	if db_key != "":
		var saved := str(Database.get_setting(db_key, ""))
		if saved != "":
			path = saved
	_tex = _load_panel_texture(path)

func _load_panel_texture(path: String) -> Texture2D:
	if path == null or path == "":
		return null
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	var img := Image.load_from_file(path)
	if img:
		return ImageTexture.create_from_image(img)
	return null

func _draw() -> void:
	if _tex != null:
		var r := Rect2(Vector2.ZERO, size)
		draw_texture_rect(_tex, r, false)
