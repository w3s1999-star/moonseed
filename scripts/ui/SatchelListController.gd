extends VBoxContainer

# SatchelListController.gd
# Shared controller for Satchel tab lists (Tasks, Relics, Items)

var category := "Items"
var row_scene: PackedScene
var data: Array = []

func set_category(new_category: String, scene: PackedScene, new_data: Array) -> void:
	category = new_category
	row_scene = scene
	data = new_data
	refresh()

func refresh() -> void:
	for c in get_children():
		c.queue_free()
	if data.size() == 0:
		var empty_lbl := Label.new()
		empty_lbl.text = "No %s yet." % category
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		add_child(empty_lbl)
		return
	for entry in data:
		var row := row_scene.instantiate()
		row.set_data(entry)
		add_child(row)
