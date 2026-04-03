extends Control

@onready var studio_room = $HBox/CenterPanel/StudioRoom
func _ready():
	# Subscribe to global state changes so UI stays in sync
	if Engine.has_singleton("SignalBus"):
		SignalBus.state_changed.connect(Callable(self, "_refresh_lists"))
	# Initial population
