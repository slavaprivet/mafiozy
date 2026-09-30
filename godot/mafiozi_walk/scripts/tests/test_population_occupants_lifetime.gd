extends SceneTree
const Population=preload("res://scripts/preview_population.gd")
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
func _initialize()->void:
	var population:=Population.new()
	var before:Array[Dictionary]=population.occupants()
	check(before.is_empty(),"unconfigured population has no door occupants")
	check(before.get_typed_builtin()==TYPE_DICTIONARY,"empty before setup retains typed caller contract")
	population.dispose()
	var after:Array[Dictionary]=population.occupants()
	check(after.is_empty(),"disposed population has no stale door occupants")
	check(after.get_typed_builtin()==TYPE_DICTIONARY,"disposed empty retains typed caller contract")
	population.dispose()
	check(population.occupants().is_empty(),"repeat disposal remains safe")
	print("POPULATION_OCCUPANTS_LIFETIME ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
