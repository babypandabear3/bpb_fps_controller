extends Area

export (NodePath) var logic_target

export (bool) var ladder = false
export (bool) var wind_force = false


var target
# Called when the node enters the scene tree for the first time.
func _ready():
	target = get_node(logic_target)



func _on_Signal_in_area_entered(signal_out):
	if not signal_out.is_in_group("Signal_out"):
		return
	if self.ladder and signal_out.ladder:
		if target.has_method("ladder_add"):
			target.ladder_add(1)
	if self.wind_force and signal_out.wind_force != 0.0:
		if target.has_method("wind_force_add"):
			target.wind_force_add(-signal_out.global_transform.basis.z * signal_out.wind_force)

func _on_Signal_in_area_exited(signal_out):
	if not signal_out.is_in_group("Signal_out"):
		return
	if self.ladder and signal_out.ladder:
		if target.has_method("ladder_add"):
			target.ladder_add(-1)
	if self.wind_force and signal_out.wind_force != 0.0:
		if target.has_method("wind_force_add"):
			target.wind_force_add(signal_out.global_transform.basis.z * signal_out.wind_force)
