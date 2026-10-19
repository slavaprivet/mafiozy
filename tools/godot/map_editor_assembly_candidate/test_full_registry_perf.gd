extends "res://test_full_registry.gd"
const ProceduralPerf = preload("res://procedural_registry_perf.gd")
const TransportPerf = preload("res://transport_registry_perf.gd")
func procedural_registry_class() -> Script: return ProceduralPerf
func transport_registry_class() -> Script: return TransportPerf
