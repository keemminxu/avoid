extends Control
## 메뉴(타이틀) 씬 스크립트
## 닉네임 입력 후 게임 씬으로 전환

# 노드 참조
@onready var nickname_input: LineEdit = $CenterContainer/VBoxContainer/NicknameInput
@onready var enter_button: Button = $CenterContainer/VBoxContainer/EnterButton


func _ready() -> void:
	# 닉네임 입력 필드에 포커스
	nickname_input.grab_focus()

	# 초기 상태: 닉네임이 비어있으므로 버튼 비활성화
	enter_button.disabled = true

	# 시그널 연결
	nickname_input.text_changed.connect(_on_nickname_text_changed)
	nickname_input.text_submitted.connect(_on_nickname_text_submitted)
	enter_button.pressed.connect(_on_enter_button_pressed)


func _on_nickname_text_changed(new_text: String) -> void:
	## 닉네임 입력 내용 변경 시 버튼 활성화/비활성화
	enter_button.disabled = new_text.strip_edges().is_empty()


func _on_nickname_text_submitted(_new_text: String) -> void:
	## Enter 키 입력 시 닉네임이 있으면 게임 씬으로 전환
	_try_enter_game()


func _on_enter_button_pressed() -> void:
	## 입장 버튼 클릭 시 게임 씬으로 전환
	_try_enter_game()


func _try_enter_game() -> void:
	## 닉네임 유효성 검사 후 게임 씬 전환
	var nickname := nickname_input.text.strip_edges()
	if nickname.is_empty():
		return

	# 싱글톤에 닉네임 저장
	GameData.player_nickname = nickname

	# 게임 씬으로 전환
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")
