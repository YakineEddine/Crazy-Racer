extends Node
## TeamManager — assignation + score d'equipe (01 §3).
## Formule par defaut : somme des positions (plus bas = mieux). Tunable.

signal teams_assigned(teams: Dictionary)
signal team_score_updated(team_id: int, new_score: float)

var teams: Dictionary = {} ## { team_id: [peer_id,...] }
var team_scores: Dictionary = {} ## { team_id: float }
var _finishes: Dictionary = {} ## { peer_id: position }

func assign_teams(format: String, player_ids: Array) -> void:
	teams.clear()
	team_scores.clear()
	_finishes.clear()
	var ids := player_ids.duplicate()
	ids.shuffle()
	match format:
		"1v1", "ffa":
			var t := 0
			for pid in ids:
				teams[t] = [pid]
				team_scores[t] = 0.0
				t += 1
		"duo":
			var t := 0
			var i := 0
			while i < ids.size():
				teams[t] = [ids[i]]
				if i + 1 < ids.size():
					teams[t].append(ids[i + 1])
				team_scores[t] = 0.0
				t += 1
				i += 2
		"squad":
			var t := 0
			var i := 0
			while i < ids.size():
				var squad: Array = []
				for k in 4:
					if i + k < ids.size():
						squad.append(ids[i + k])
				teams[t] = squad
				team_scores[t] = 0.0
				t += 1
				i += 4
		_:
			teams[0] = ids
			team_scores[0] = 0.0
	teams_assigned.emit(teams)

func register_finish(peer_id: int, position: int) -> void:
	_finishes[peer_id] = position
	var tid := team_of(peer_id)
	if tid != -1:
		var s := compute_team_score(tid)
		team_scores[tid] = s
		team_score_updated.emit(tid, s)

func team_of(peer_id: int) -> int:
	for tid in teams:
		if peer_id in teams[tid]:
			return int(tid)
	return -1

func compute_team_score(team_id: int) -> float:
	# Somme des positions des coequipiers ayant fini ; sans fin = penalite 99.
	var total := 0.0
	for pid in teams.get(team_id, []):
		total += float(_finishes.get(pid, 99))
	return total

func get_team_ranking() -> Array:
	var tids := teams.keys()
	tids.sort_custom(func(a, b) -> bool: return float(team_scores.get(a, 9999.0)) < float(team_scores.get(b, 9999.0)))
	return tids
