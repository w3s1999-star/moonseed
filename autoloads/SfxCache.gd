# Loads and caches arbitrary SFX for one-off playback
extends Node

var _cache := {}

func get_stream(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if ResourceLoader.exists(path):
		var stream = load(path)
		if stream and stream is AudioStream:
			_cache[path] = stream
			return stream
	return null
