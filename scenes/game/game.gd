extends Node2D
## 메인 게임 씬 스크립트
## 원형 경기장(하늘 배경 + 구름 + 풀 데코 + 금색 링), 점수 관리, 생존 시간 표시,
## 게임오버/재시작, 스포너/난이도/충돌 시스템 + 오브젝트 풀 통합을 담당한다.
## 모든 비주얼은 노드 기반이며, _draw() 는 사용하지 않는다.

# 원형 경기장 파라미터
const ARENA_CENTER: Vector2 = Vector2(640, 360)
const ARENA_RADIUS: float = 320.0

# Polygon2D 로 원을 근사할 때 사용할 분할 수
const ARENA_POLYGON_SEGMENTS: int = 96

# 풀 데코 스프라이트 개수 (경기장 내부 랜덤 스캐터)
const GRASS_DECOR_COUNT: int = 36
# 풀/덤불 데코 타일 (Kenney pixel-shmup 의 잔디 변형 타일들).
# tile_0036: 풀 패치, tile_0048: 덤불, tile_0049: 작은 식물
const GRASS_TILE_PATHS: Array[String] = [
	"res://assets/sprites/kenney_pixel-shmup/Tiles/tile_0036.png",
	"res://assets/sprites/kenney_pixel-shmup/Tiles/tile_0048.png",
	"res://assets/sprites/kenney_pixel-shmup/Tiles/tile_0049.png",
]
# 풀 데코 스케일 — 16x16 원본을 약 24x24 로 표시
const GRASS_DECOR_SCALE: Vector2 = Vector2(1.5, 1.5)

# 구름 파라미터
const CLOUD_COUNT: int = 6
const CLOUD_SPEED_MIN: float = 12.0
const CLOUD_SPEED_MAX: float = 28.0
const CLOUD_COLOR: Color = Color(1.0, 1.0, 1.0, 0.85)
# 구름 타원 반지름 (각 구름은 여러 개의 겹친 타원으로 구성)
const CLOUD_BLOB_COUNT: int = 4
const CLOUD_BLOB_RADIUS_MIN: float = 18.0
const CLOUD_BLOB_RADIUS_MAX: float = 32.0

# 현재 점수
var score: int = 0
# 생존 시간 (초)
var elapsed_time: float = 0.0
# 게임 진행 중 여부
var is_game_running: bool = true

# 노드 참조
@onready var player: CharacterBody2D = $Player
@onready var obstacle_container: Node2D = $ObstacleContainer
@onready var arena_interior: Polygon2D = $ArenaInterior
@onready var arena_border: Line2D = $ArenaBorder
@onready var grass_decor: Node2D = $GrassDecor
@onready var cloud_layer: Node2D = $CloudLayer
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

# 구름 데이터: {node: Node2D, speed: float}
var _clouds: Array[Dictionary] = []


func _ready() -> void:
	# 비주얼 레이어 초기화
	_build_arena_polygon()
	_build_arena_border()
	_build_grass_decor()
	_build_clouds()

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
	# 구름은 게임오버 이후에도 움직이도록 is_game_running 체크 앞에 처리
	_update_clouds(delta)

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
	## 같은 프레임에 여러 장애물이 동시 충돌하면 body_entered가 반복 발행되어
	## game_over가 여러 번 불릴 수 있으므로 재진입을 차단한다.
	if not is_game_running:
		return
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


# ─────────────────────────────────────────────────────────────
# 경기장 비주얼 빌드 헬퍼
# ─────────────────────────────────────────────────────────────

func _build_arena_polygon() -> void:
	## ArenaInterior(Polygon2D) 에 경기장 원형 바닥을 근사하는 정다각형 점들을 주입.
	var pts: PackedVector2Array = PackedVector2Array()
	for i in ARENA_POLYGON_SEGMENTS:
		var angle: float = (float(i) / float(ARENA_POLYGON_SEGMENTS)) * TAU
		pts.append(ARENA_CENTER + Vector2.from_angle(angle) * ARENA_RADIUS)
	arena_interior.polygon = pts


func _build_arena_border() -> void:
	## ArenaBorder(Line2D) 에 닫힌 원을 이루는 점들을 주입하여 금색 링을 그린다.
	var pts: PackedVector2Array = PackedVector2Array()
	var segments: int = ARENA_POLYGON_SEGMENTS
	for i in segments + 1:
		var angle: float = (float(i) / float(segments)) * TAU
		pts.append(ARENA_CENTER + Vector2.from_angle(angle) * ARENA_RADIUS)
	arena_border.points = pts


func _build_grass_decor() -> void:
	## 경기장 내부에 풀 스프라이트를 랜덤 배치한다.
	## 플레이어 중심 근처에는 풀이 없도록 최소 반경을 둔다.
	var grass_textures: Array[Texture2D] = []
	for path in GRASS_TILE_PATHS:
		var tex := load(path) as Texture2D
		if tex != null:
			grass_textures.append(tex)

	if grass_textures.is_empty():
		return

	const MIN_RADIUS_FROM_CENTER: float = 60.0
	const MAX_RADIUS: float = ARENA_RADIUS - 24.0

	for i in GRASS_DECOR_COUNT:
		var sprite := Sprite2D.new()
		sprite.texture = grass_textures[randi() % grass_textures.size()]
		sprite.scale = GRASS_DECOR_SCALE

		# 경기장 내부 균등 분포 샘플링 (sqrt 로 면적 균등)
		var angle: float = randf() * TAU
		var radius: float = sqrt(randf()) * (MAX_RADIUS - MIN_RADIUS_FROM_CENTER) + MIN_RADIUS_FROM_CENTER
		sprite.position = ARENA_CENTER + Vector2.from_angle(angle) * radius

		# 아주 살짝 랜덤 회전으로 단조로움 방지
		sprite.rotation = randf_range(-0.2, 0.2)
		grass_decor.add_child(sprite)


func _build_clouds() -> void:
	## 경기장 바깥 하늘 영역(주로 화면 상단 띠)에 구름을 배치한다.
	## 경기장 원형이 ARENA_CENTER(640,360) ± ARENA_RADIUS(320) 이라 화면 상단의
	## y < 40 영역이 경기장 위쪽 시야이며, 일부 구름은 화면 경계 밖으로 일부러
	## 걸쳐서 깊이감을 준다.
	for i in CLOUD_COUNT:
		var cloud := _make_cloud_node()
		cloud.position = Vector2(
			randf_range(-100.0, 1380.0),
			randf_range(-30.0, 50.0)
		)
		cloud_layer.add_child(cloud)

		var speed: float = randf_range(CLOUD_SPEED_MIN, CLOUD_SPEED_MAX)
		_clouds.append({"node": cloud, "speed": speed})


func _make_cloud_node() -> Node2D:
	## 여러 겹친 원형 Polygon2D 를 가진 구름 하나를 만든다.
	var cloud := Node2D.new()

	for j in CLOUD_BLOB_COUNT:
		var blob := Polygon2D.new()
		var r: float = randf_range(CLOUD_BLOB_RADIUS_MIN, CLOUD_BLOB_RADIUS_MAX)
		blob.polygon = _circle_polygon(r, 16)
		blob.color = CLOUD_COLOR
		# 블롭을 살짝 오프셋하여 울퉁불퉁한 구름 형태를 만든다
		blob.position = Vector2(
			randf_range(-r * 0.6, r * 0.6),
			randf_range(-r * 0.3, r * 0.3)
		)
		cloud.add_child(blob)

	return cloud


func _circle_polygon(radius: float, segments: int) -> PackedVector2Array:
	## 주어진 반지름의 원을 근사하는 다각형 점 배열을 반환한다.
	var pts: PackedVector2Array = PackedVector2Array()
	for i in segments:
		var angle: float = (float(i) / float(segments)) * TAU
		pts.append(Vector2.from_angle(angle) * radius)
	return pts


func _update_clouds(delta: float) -> void:
	## 구름을 왼쪽에서 오른쪽으로 이동시키고, 화면 밖으로 나가면 왼쪽으로 순환시킨다.
	for entry in _clouds:
		var node: Node2D = entry["node"]
		var speed: float = entry["speed"] as float
		node.position.x += speed * delta
		if node.position.x > 1400.0:
			node.position.x = -120.0
			node.position.y = randf_range(-30.0, 50.0)
