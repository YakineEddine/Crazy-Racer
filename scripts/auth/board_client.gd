class_name BoardClient
extends RefCounted
## Logique classement pure (UI_UX §6) : URLs PostgREST, parsing, format exact.
## Sans reseau ni etat — le HTTP passe par SupaAuth.db_get/db_post (ecrans).
## Filtre anti-guest ici AUSSI (defense en profondeur ; RLS fait foi cote serveur).

const TOP_LIMIT := 50

static func top_path(map_id: String) -> String:
	return "/rest/v1/race_results?map_id=eq." + map_id.uri_encode() \
		+ "&user_id=not.is.null&order=total_ms.asc&limit=" + str(TOP_LIMIT) \
		+ "&select=user_id,display_name,total_ms,team_name,members"

static func rank_path(map_id: String, total_ms: int) -> String:
	return "/rest/v1/race_results?map_id=eq." + map_id.uri_encode() \
		+ "&user_id=not.is.null&total_ms=lt." + str(total_ms) + "&select=id&limit=1"

static func mine_path(map_id: String, user_id: String) -> String:
	return "/rest/v1/race_results?map_id=eq." + map_id.uri_encode() \
		+ "&user_id=eq." + user_id.uri_encode() + "&order=total_ms.asc&limit=1" \
		+ "&select=total_ms,display_name"

## Meilleur chrono perso ({total_ms, name}) ou {} si aucun.
static func parse_mine(data: Variant) -> Dictionary:
	if data is Array:
		for row in data:
			if row is Dictionary and int(row.get("total_ms", 0)) > 0:
				return {"total_ms": int(row.get("total_ms", 0)), "name": row_name(row)}
	return {}

static func row_name(entry: Dictionary) -> String:
	if str(entry.get("team_name", "")) != "":
		return str(entry.get("team_name"))
	if str(entry.get("members", "")) != "":
		return str(entry.get("members"))
	var nm := str(entry.get("display_name", ""))
	return nm if nm != "" else "Joueur"

## Meilleur temps par user_id, tries croissants, top 10 [{rank,name,total_ms,user_id}].
static func parse_top_rows(data: Variant) -> Array:
	var best := {}
	if data is Array:
		for row in data:
			if not (row is Dictionary):
				continue
			var uid := str(row.get("user_id", ""))
			if uid == "":
				continue
			var t := int(row.get("total_ms", 0))
			if t <= 0:
				continue
			if not best.has(uid) or t < int(best[uid].get("total_ms", 0)):
				best[uid] = {"user_id": uid, "name": row_name(row), "total_ms": t}
	var arr: Array = best.values()
	arr.sort_custom(func(a: Variant, b: Variant) -> bool: return int(a.get("total_ms", 0)) < int(b.get("total_ms", 0)))
	var out: Array = []
	for i in mini(arr.size(), 10):
		var e: Dictionary = arr[i]
		out.append({"rank": i + 1, "name": str(e.get("name", "")), "total_ms": int(e.get("total_ms", 0)), "user_id": str(e.get("user_id", ""))})
	return out

static func format_row(rank: int, name: String) -> String:
	if rank == 1:
		return "🥇 " + name
	if rank == 2:
		return "🥈 " + name
	if rank == 3:
		return "🥉 " + name
	return "%d. %s" % [rank, name]

## Lignes exactes §6 ; "" = separateur avant le rang perso (hors top 10 uniquement).
static func format_board(top: Array, own_rank: int, own_name: String) -> Array:
	var lines: Array = []
	for e in top:
		if e is Dictionary:
			lines.append(format_row(int(e.get("rank", 0)), str(e.get("name", ""))))
	if own_rank > 0:
		var dup := false
		for e in top:
			if e is Dictionary and int(e.get("rank", 0)) == own_rank:
				dup = true
		if not dup:
			lines.append("")
			lines.append(format_row(own_rank, own_name))
	return lines

static func build_submit_row(user_id: String, display_name: String, map_id: String, mode: String, total_ms: int, team_name: String, members: String) -> Dictionary:
	var nm := display_name if display_name != "" else "Joueur"
	return {
		"user_id": (null if user_id == "" else user_id),
		"display_name": nm,
		"map_id": map_id,
		"mode": mode,
		"total_ms": maxi(1, total_ms),
		"team_name": (null if team_name == "" else team_name),
		"members": (null if members == "" else members),
	}
