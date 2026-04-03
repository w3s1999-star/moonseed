extends Control

signal studio_place(curio_id)

@export var curio_id: int = -1

@onready var studio_button = $HBox/StudioButton
@onready var archive_button = $HBox/ArchiveButton
@onready var delete_button = $HBox/DeleteButton

func _ready():
    studio_button.connect("pressed", Callable(self, "_on_studio_pressed"))
    archive_button.connect("pressed", Callable(self, "_on_archive_pressed"))
    delete_button.connect("pressed", Callable(self, "_on_delete_pressed"))

func _on_studio_pressed():
    emit_signal("studio_place", curio_id)

func _on_archive_pressed():
    # Replace with actual archive call
    print("Archive curio:", curio_id)

func _on_delete_pressed():
    # Replace with actual delete call
    print("Delete curio:", curio_id)
