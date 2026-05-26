class_name DayCycleSystem
extends RefCounted

enum DayPhase { DAY, NIGHT }

signal phase_changed(new_phase: DayPhase)
signal stamina_changed(current: int, max: int)

var phase: int = DayPhase.DAY
var stamina: int = 5
var max_stamina: int = 5

func start_day() -> void:
	phase = DayPhase.DAY
	stamina = max_stamina
	stamina_changed.emit(stamina, max_stamina)

func spend_stamina(amount: int) -> bool:
	if phase != DayPhase.DAY or stamina < amount:
		return false
	stamina -= amount
	stamina_changed.emit(stamina, max_stamina)
	return true

func next_phase() -> void:
	if phase == DayPhase.DAY:
		phase = DayPhase.NIGHT
		phase_changed.emit(phase)
	else:
		phase = DayPhase.DAY
		start_day()
		phase_changed.emit(phase)
