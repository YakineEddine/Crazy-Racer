extends Node3D
## Scene racine (boot). Enregistre les layers aupres de GameManager.
## Contient : MapHolder (3D), UILayer (CanvasLayer), ItemSystem, lumieres de secours.

func _ready() -> void:
	var ui_layer: CanvasLayer = $UILayer as CanvasLayer
	var holder: Node3D = $MapHolder as Node3D
	GameManager.register_layers(ui_layer, holder)
	if GameManager.current_phase != GameManager.MatchPhase.MENU:
		GameManager.change_phase(GameManager.MatchPhase.MENU)
	else:
		# Force l'affichage du menu au boot.
		GameManager.change_phase(GameManager.MatchPhase.LOBBY)
		GameManager.change_phase(GameManager.MatchPhase.MENU)
