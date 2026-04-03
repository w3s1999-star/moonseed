extends Node

signal preload_progress(done: int, total: int, path: String, resource)

var _requests: Array = []
var _cache: Dictionary = {}
var _total_requests: int = 0
var _done_requests: int = 0

func _ready() -> void:
	set_process(false)

func preload_paths(paths: Array, progress_cb: Callable = Callable()) -> void:
	var total := 0
	for p in paths:
		if _cache.has(p):
			continue
		# Request threaded load for the path (non-blocking)
		ResourceLoader.load_threaded_request(p)
		_requests.append(p)
		total += 1
	_total_requests = total
	_done_requests = 0
	if _requests.is_empty():
		set_process(false)
		return

	var finished: Array = []
	for p in _requests:
		var prog: Array = []
		var status := ResourceLoader.load_threaded_get_status(p, prog)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var res := ResourceLoader.load_threaded_get(p)
			if res != null:
				_cache[p] = res
			_done_requests += 1
			emit_signal("preload_progress", _done_requests, _total_requests, p, res)
			if _total_requests > 0:
				var percent := float(_done_requests) / float(_total_requests)
				SignalBus.load_progress_updated.emit(percent)
		elif status == ResourceLoader.THREAD_LOAD_FAILED:
			_done_requests += 1
			push_error("AsyncLoader: failed to load " + str(p))
			if _total_requests > 0:
				var percent_fail := float(_done_requests) / float(_total_requests)
				SignalBus.load_progress_updated.emit(percent_fail)
		finished.append(p)
	for f in finished:
		_requests.erase(f)

	if _requests.is_empty():
		set_process(false)

func get_cached(path: String):
	return _cache.get(path, null)

func is_loaded(path: String) -> bool:
	return _cache.has(path)
