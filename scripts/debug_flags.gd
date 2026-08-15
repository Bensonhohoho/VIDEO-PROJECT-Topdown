extends Node

signal godmode_changed(enabled: bool)
signal console_input_active_changed(enabled: bool)

var godmode_enabled := false
var console_input_active := false


func is_debug_build() -> bool:
	return OS.has_feature("debug") or OS.has_feature("editor")


func is_godmode_enabled() -> bool:
	return is_debug_build() and godmode_enabled


func is_console_input_active() -> bool:
	return is_debug_build() and console_input_active


func set_godmode_enabled(enabled: bool) -> void:
	if not is_debug_build():
		return

	if godmode_enabled == enabled:
		return

	godmode_enabled = enabled
	godmode_changed.emit(godmode_enabled)


func toggle_godmode() -> bool:
	set_godmode_enabled(not godmode_enabled)
	return godmode_enabled


func set_console_input_active(enabled: bool) -> void:
	if not is_debug_build():
		enabled = false

	if console_input_active == enabled:
		return

	console_input_active = enabled
	console_input_active_changed.emit(console_input_active)
