extends Node2D
## 메인 게임 씬 스크립트
## 원형 경기장 배경 렌더링, 점수 관리, 생존 시간 표시, 게임오버/재시작
## 스포너/난이도/충돌 시스템 + 오브젝트 풀 통합

# 원형 경기장 파라미터
const ARENA_CENTER: Vector2 = Vector2(640, 360)
const ARENA_RADIUS: float = 320.0
const ARENA_BORDER_WIDTH: float = 4.0
const ARENA_BORDER_COLOR: Color = Color("#2d5a1e")
const ARENA_INNER_COLOR: Color = Color("#0f0f2e")
const ARENA_OUTER_COLOR: Color = Color("#0a0a1a")

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
@onready var nickname_label: Label = $HUD/NicknameLabel
@onready var score_timer: Timer = $ScoreTimer
@onready var game_over_panel: ColorRect = $HUD/GameOverPanel
@onready var game_over_label: Label = $HUD/GameOverPanel/GameOverLabel
@onready var restart_label: Label = $HUD/GameOverPanel/RestartLabel
@onready var difficulty_manager: DifficultyManager = $DifficultyManager
@onready var obstacle_spawner: ObstacleSpawner = $ObstacleSpawner
@onready var collision_handler: CollisionHandler = $CollisionHandler

# 장애물 씬 프리로드
var _obstacle_scenes: Array[PackedScene] = []

# 오브젝트 풀 (장애물 타입별)
var _obstacle_pools: Array[ObjectPool] = []


func _ready() -> void:
	# 게임오버 패널 숨김
	game_over_panel.visible = false

	# 닉네임 표시
	nickname_label.text = GameData.player_nickname

	# 장애물 씬 로드 (인덱스 0: 기본, 1: 빠른, 2: 큰, 3: 추적)
	_obstacle_scenes = [
		preload("res://scenes/obstacles/obstacle.tscn"),
		preload("res://scenes/obstacles/obstacle_fast.tscn"),
		preload("res://scenes/obstacles/obstacle_large.tscn"),
		preload("res://scenes/obstacles/obstacle_homing.tscn"),
	]

	# 각 장애물 타입별 오브젝트 풀 생성
	for scene in _obstacle_scenes:
		var pool := ObjectPool.new()
		pool.pool_scene = scene
		pool.initial_size = 30
		pool.max_size = 120
		pool.container = obstacle_container
		add_child(pool)
		_obstacle_pools.append(pool)

	# 스포너 설정
	obstacle_spawner.pools = _obstacle_pools
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


func _draw() -> void:
	# 바깥 배경 (전체 화면을 어두운 색으로 채움)
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), ARENA_OUTER_COLOR)
	# 원형 경기장 내부
	draw_circle(ARENA_CENTER, ARENA_RADIUS, ARENA_INNER_COLOR)
	# 원형 경기장 테두리 (녹색 링)
	draw_arc(ARENA_CENTER, ARENA_RADIUS, 0.0, TAU, 128, ARENA_BORDER_COLOR, ARENA_BORDER_WIDTH)


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

	# 모든 풀의 활성 오브젝트 반환
	for pool in _obstacle_pools:
		pool.release_all()

	# 게임오버 패널에 최종 점수/시간 표시
	game_over_label.text = "GAME OVER\n점수: %d\n시간: %.2f초" % [score, elapsed_time]
	restart_label.text = "Enter 키를 눌러 재시작"
	game_over_panel.visible = true


func restart() -> void:
	## 현재 씬 리로드하여 재시작
	get_tree().reload_current_scene()


func _update_score_label() -> void:
	## 점수 라벨 갱신
	score_label.text = "점수: %d" % score


func _update_time_label() -> void:
	## 생존 시간 라벨 갱신 (소수점 둘째자리)
	time_label.text = "%.2f초" % elapsed_time
