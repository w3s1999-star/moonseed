extends Node
class_name RollResolutionQueue

## Phased event queue for dice roll resolution.
## Owns sequence order only — not particle internals or scoring math.

signal phase_started(phase_name: String)
signal phase_finished(phase_name: String)
signal queue_finished(summary: Dictionary)

var _steps: Array[Callable] = []
var _is_running: bool = false
var _context: Dictionary = {}

func begin(context: Dictionary) -> void:
	if _is_running:
		return
	_is_running = true
	_context = context
	_build_steps()
	await _run_steps()
	_is_running = false
	queue_finished.emit(_context)

func _build_steps() -> void:
	_steps.clear()
	_steps.append(_phase_spawn_moondrops)
	_steps.append(_phase_merge)
	_steps.append(_phase_crystallize)
	_steps.append(_phase_final_burst)

func _run_steps() -> void:
	for step: Callable in _steps:
		var phase_name: String = step.get_method()
		phase_started.emit(phase_name)
		await step.call()
		phase_finished.emit(phase_name)

func _phase_spawn_moondrops() -> void:
	# Handled by RewardFXController via signal
	pass

func _phase_merge() -> void:
	# Handled by RewardFXController via signal
	pass

func _phase_crystallize() -> void:
	# Handled by RewardFXController via signal
	pass

func _phase_final_burst() -> void:
	# Handled by RewardFXController via signal
	pass