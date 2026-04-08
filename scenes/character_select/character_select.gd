extends Control
## 캐릭터 선택 씬
## 두 개의 강아지 카드(호두/몽구) 중 하나를 선택한 뒤 게임 씬으로 진입한다.
## 좌우 방향키/클릭으로 선택 전환, Enter/스페이스/버튼으로 확정.

## 선택 가능한 캐릭터 ID 목록
const CHARACTERS: Array[String] = ["hodu", "monggu"]

# 현재 하이라이트된 인덱스
var _selected_index: int = 0

# 노드 참조
@onready var hodu_card: Panel = $CenterContainer/VBoxContainer/CardsRow/HoduCard
@onready var monggu_card: Panel = $CenterContainer/VBoxContainer/CardsRow/MongguCard
@onready var confirm_button: Button = $CenterContainer/VBoxContainer/ConfirmButton
@onready var back_button: Button = $BackButton


func _ready() -> void:
	# 이전에 선택된 캐릭터가 있으면 인덱스 복원
	var prev_idx := CHARACTERS.find(GameData.selected_character)
	if prev_idx >= 0:
		_selected_index = prev_idx

	# 카드 클릭 처리 — Panel에 gui_input 연결
	hodu_card.gui_input.connect(_on_card_input.bind(0))
	monggu_card.gui_input.connect(_on_card_input.bind(1))

	confirm_button.pressed.connect(_on_confirm_pressed)
	back_button.pressed.connect(_on_back_pressed)

	_update_selection_visual()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("move_left"):
		_set_selection(_selected_index - 1)
	elif event.is_action_pressed("move_right"):
		_set_selection(_selected_index + 1)
	elif event.is_action_pressed("ui_accept"):
		_on_confirm_pressed()


func _on_card_input(event: InputEvent, index: int) -> void:
	## 카드를 클릭하면 해당 카드로 선택을 이동한다.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_set_selection(index)


func _set_selection(new_index: int) -> void:
	## 선택 인덱스를 0..CHARACTERS.size()-1 범위로 클램프하여 업데이트한다.
	_selected_index = clampi(new_index, 0, CHARACTERS.size() - 1)
	_update_selection_visual()


func _update_selection_visual() -> void:
	## 선택된 카드만 하이라이트 테두리를 표시한다.
	var cards: Array[Panel] = [hodu_card, monggu_card]
	for i in cards.size():
		var card := cards[i]
		if i == _selected_index:
			card.add_theme_stylebox_override("panel", _make_selected_stylebox())
		else:
			card.add_theme_stylebox_override("panel", _make_default_stylebox())


func _make_default_stylebox() -> StyleBoxFlat:
	## 비선택 카드용 스타일박스
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.15, 0.25, 1.0)
	sb.border_color = Color(0.3, 0.35, 0.5, 1.0)
	sb.border_width_left = 4
	sb.border_width_right = 4
	sb.border_width_top = 4
	sb.border_width_bottom = 4
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	return sb


func _make_selected_stylebox() -> StyleBoxFlat:
	## 선택된 카드용 하이라이트 스타일박스 (황금색 테두리)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.22, 0.35, 1.0)
	sb.border_color = Color(1.0, 0.82, 0.2, 1.0)
	sb.border_width_left = 6
	sb.border_width_right = 6
	sb.border_width_top = 6
	sb.border_width_bottom = 6
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	return sb


func _on_confirm_pressed() -> void:
	## 선택한 캐릭터를 GameData에 저장하고 게임 씬으로 전환한다.
	GameData.selected_character = CHARACTERS[_selected_index]
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")


func _on_back_pressed() -> void:
	## 메뉴 씬으로 복귀한다.
	get_tree().change_scene_to_file("res://scenes/menu/menu.tscn")
