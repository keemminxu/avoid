extends Node2D
## 메인 게임 씬 스크립트
## 점수 관리, 생존 시간 표시, 게임오버/재시작 처리
## 스포너/난이도/충돌 시스템 통합

# 현재 점수
var score: int = 0
# 생존 시간 (초)
var elapsed_time: float = 0.0
# 게임 진행 중 여부
var is_game_running: bool = true

# 노드 참조
@onready var player: CharacterBody2D = $Player
@onready var obstacle_container: Node2D = $ObstacleContainer
@onready var score_label: Label = $HUD/ScoreLabel
@onready var time_label: Label = $HUD/TimeLabel
@onready var score_timer: Timer = $ScoreTimer
@onready var game_over_panel: ColorRect = $HUD/GameOverPanel
@onready var game_over_label: Label = $HUD/GameOverPanel/GameOverLabel
@onready var restart_label: Label = $HUD/GameOverPanel/RestartLabel
@onready var difficulty_manager: DifficultyManager = $DifficultyManager
@onready var obstacle_spawner: ObstacleSpawner = $ObstacleSpawner
@onready var collision_handler: CollisionHandler = $CollisionHandler

# 장애물 씬 프리로드
var _obstacle_scenes: Array[PackedScene] = []


func _ready() -> void:
	# 게임오버 패널 숨김
	game_over_panel.visible = false

	# 장애물 씬 로드
	_obstacle_scenes = [
		preload("res://scenes/obstacles/obstacle.tscn"),
		preload("res://scenes/obstacles/obstacle_fast.tscn"),
		preload("res://scenes/obstacles/obstacle_large.tscn"),
		preload("res://scenes/obstacles/obstacle_diagonal.tscn"),
	]

	# 스포너 설정
	obstacle_spawner.obstacle_scenes = _obstacle_scenes
	obstacle_spawner.obstacle_container = obstacle_container
	obstacle_spawner.difficulty_manager = difficulty_manager
	obstacle_spawner.player_target = player
	obstacle_spawner.collision_handler = collision_handler

	# 충돌 핸들러 설정
	collision_handler.player = player
	collision_handler.player_hit.connect(_on_player_hit)

	# 점수 타이머 시작 (1초 간격)
	score_timer.wait_time = 1.0
	score_timer.timeout.connect(_on_score_timer_timeout)
	score_timer.start()

	# 플레이어 사망 시그널 연결
	player.player_died.connect(_on_player_died)

	# 초기 HUD 업데이트
	_update_score_label()
	_update_time_label()

	# 게임 시작 — 난이도 + 스포너 + 무적 시간 활성화
	difficulty_manager.start()
	obstacle_spawner.start_spawning()
	collision_handler.activate_invincibility()


func _process(delta: float) -> void:
	if not is_game_running:
		# 게임오버 상태에서 재시작 입력 확인
		if Input.is_action_just_pressed("ui_accept"):
			restart()
		return

	# 생존 시간 누적
	elapsed_time += delta
	_update_time_label()


func _on_score_timer_timeout() -> void:
	## 1초마다 점수 1 증가
	if is_game_running:
		score += 1
		_update_score_label()


func _on_player_died() -> void:
	## 플레이어 사망 시 게임오버 처리
	game_over()


func _on_player_hit() -> void:
	## 충돌 핸들러가 플레이어 피격 감지 시 호출
	player.die()


func game_over() -> void:
	## 게임오버 — 패널 표시, 게임 중지
	is_game_running = false
	score_timer.stop()
	obstacle_spawner.stop_spawning()
	difficulty_manager.stop()

	# 남아있는 장애물 모두 제거
	for child in obstacle_container.get_children():
		child.queue_free()

	# 게임오버 패널에 최종 점수 표시
	game_over_label.text = "GAME OVER\n점수: %d\n시간: %s" % [score, _format_time(elapsed_time)]
	restart_label.text = "Enter 키를 눌러 재시작"
	game_over_panel.visible = true


func restart() -> void:
	## 현재 씬 리로드하여 재시작
	get_tree().reload_current_scene()


func _update_score_label() -> void:
	## 점수 라벨 갱신
	score_label.text = "점수: %d" % score


func _update_time_label() -> void:
	## 생존 시간 라벨 갱신 (mm:ss 형식)
	time_label.text = _format_time(elapsed_time)


func _format_time(time_seconds: float) -> String:
	## 초를 mm:ss 형식 문자열로 변환
	var total_seconds := int(time_seconds)
	var minutes := total_seconds / 60
	var seconds := total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]
