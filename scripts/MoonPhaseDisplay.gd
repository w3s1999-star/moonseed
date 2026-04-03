extends ColorRect
class_name MoonPhaseDisplay

const MOON_SHADER := preload("res://shaders/moon_phase.gdshader")

static var _shared_noise_texture: Texture2D

var _moon_material: ShaderMaterial

func _ready() -> void:
	color = Color.WHITE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_material()

func set_phase_data(phase: Dictionary) -> void:
	_ensure_material()
	_moon_material.set_shader_parameter("phase_pos", float(phase.get("pos", 0.5)))

func _ensure_material() -> void:
	if _moon_material != null:
		return
	_moon_material = ShaderMaterial.new()
	_moon_material.shader = MOON_SHADER
	_moon_material.set_shader_parameter("noise_texture", _get_noise_texture())
	material = _moon_material

func _get_noise_texture() -> Texture2D:
	if _shared_noise_texture != null:
		return _shared_noise_texture
	var noise := FastNoiseLite.new()
	noise.seed = 71284
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.065
	noise.fractal_octaves = 3
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in range(128):
		for x in range(128):
			var sample := noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			image.set_pixel(x, y, Color(sample, sample, sample, 1.0))
	_shared_noise_texture = ImageTexture.create_from_image(image)
	return _shared_noise_texture
