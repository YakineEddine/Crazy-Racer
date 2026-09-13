class_name ModelFactory
extends RefCounted
## Instancie les modeles FBX externes (Quaternius CC0) : anim, echelle, roues.
## Tout est defensif (nom d'anim/clip inconnu => fallback silencieux).

static func instance(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	var n := ps.instantiate()
	return n as Node3D

## Joue la premiere anim preferee trouvee (ex ["Idle"], ["Run","Walk"]), sinon la 1re.
static func play_anim(root: Node, preferred: Array) -> String:
	var players := root.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return ""
	var ap := players[0] as AnimationPlayer
	var lst := ap.get_animation_list()
	if lst.is_empty():
		return ""
	for want in preferred:
		for a in lst:
			if str(a).to_lower().contains(str(want).to_lower()):
				ap.play(str(a))
				return str(a)
	ap.play(lst[0])
	return str(lst[0])

## Cache les roues statiques des modeles de voitures (nos roues proceduralles tournent).
static func hide_wheels(root: Node) -> int:
	var n := 0
	var stack: Array = [root]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		for c in cur.get_children():
			var nm := str(c.name).to_lower()
			if nm.contains("wheel") or nm.contains("tire") or nm.contains("tyre"):
				c.visible = false
				n += 1
			else:
				stack.append(c)
	return n

## Echelle uniforme directe (dimensions mesurees sur les .obj, pieds a y~=0).
static func scale_to(node: Node3D, s: float) -> void:
	node.scale = Vector3.ONE * s
