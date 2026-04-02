class_name ObstacleSpawner
extends Node2D

## 장애물 스포너
## 화면 4면(상/하/좌/우)에서 랜덤하게 장애물을 생성한다.
## DifficultyManager와 연동하여 난이도에 맞는 장애물을 스폰.

# 스폰 가능한 장애물 씬 목록 — 에디터에서 할당
# 인덱스 0: 기본 장애물, 1: 빠른 장애물, 2: 큰 장애물, 3: 대각선 장애물
@export var obstacle_scenes: Array[PackedScene] = []

# 기본 스폰 간격 (초). DifficultyManager가 연결되면 해당 값으로 덮어쓴다.
@export var spawn_interval: float = 1.0

# 스폰된 장애물이 추가될 부모 노드 — 에디터에서 할당
@export var obstacle_container: Node2D

# 난이도 관리자 참조 (선택적) — 연결하면 난이도 기반 스폰 제어
@export var difficulty_manager: DifficultyManager

# 플레이어 노드 참조 (선택적) — 연결하면 플레이어 방향 에이밍 활성화
@export var player_target: Node2D

# 충돌 관리자 참조 (선택적) — 연결하면 스폰된 장애물에 자동으로 충돌 시그널 연결
@export var collision_handler: CollisionHandler

# 플레이어 방향 에이밍 강도 (0.0 = 완전 랜덤, 1.0 = 플레이어 직행)
@export_range(0.0, 1.0) var aim_strength: float = 0.0

# 장애물 기본 이동 속도 (px/sec)
@export var base_speed: float = 200.0

# 화면 밖 스폰 오프셋 (px) — 화면 경계에서 이만큼 벗어난 곳에서 스폰
@export var spawn_offset: float = 50.0

# 스폰 방향 열거형
enum SpawnSide { TOP, BOTTOM, LEFT, RIGHT }

# 내부 스폰 타이머
var _spawn_timer: Timer

# 뷰포트 크기 캐시
var _viewport_size: Vector2


func _ready() -> void:
	_viewport_size = get_viewport_rect().size
	_setup_spawn_timer()

	# 난이도 관리자가 연결되어 있으면 난이도 변경 시그널 구독
	if difficulty_manager:
		difficulty_manager.difficulty_changed.connect(_on_difficulty_changed)


## 장애물 스폰을 시작한다.
func start_spawning() -> void:
	_update_spawn_interval()
	_spawn_timer.start()


## 장애물 스폰을 정지한다.
func stop_spawning() -> void:
	_spawn_timer.stop()


# 스폰 타이머를 생성하고 설정한다.
func _setup_spawn_timer() -> void:
	_spawn_timer = Timer.new()
	_spawn_timer.one_shot = false
	_spawn_timer.wait_time = spawn_interval
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(_spawn_timer)


# 현재 난이도에 맞게 스폰 간격을 갱신한다.
func _update_spawn_interval() -> void:
	if difficulty_manager:
		_spawn_timer.wait_time = difficulty_manager.get_spawn_interval()
	else:
		_spawn_timer.wait_time = spawn_interval


# 난이도가 변경되었을 때 스폰 간격을 갱신한다.
func _on_difficulty_changed(_level: int) -> void:
	_update_spawn_interval()


# 스폰 타이머가 만료될 때마다 호출. 장애물 하나를 스폰한다.
func _on_spawn_timer_timeout() -> void:
	_spawn_obstacle()


# 장애물을 스폰한다.
# 1. 사용 가능한 장애물 중 랜덤 선택
# 2. 화면 4면 중 랜덤 스폰 위치 결정
# 3. 이동 방향 계산 (에이밍 포함)
# 4. 씬 인스턴스 생성 후 컨테이너에 추가
func _spawn_obstacle() -> void:
	if obstacle_scenes.is_empty():
		push_warning("ObstacleSpawner: obstacle_scenes 배열이 비어있습니다.")
		return

	if not obstacle_container:
		push_warning("ObstacleSpawner: obstacle_container가 설정되지 않았습니다.")
		return

	# 뷰포트 크기 갱신 (런타임 리사이즈 대응)
	_viewport_size = get_viewport_rect().size

	# 난이도에 따른 사용 가능 장애물 인덱스 결정
	var available_indices: Array
	if difficulty_manager:
		available_indices = difficulty_manager.get_available_obstacles()
	else:
		# 난이도 관리자가 없으면 모든 장애물 사용
		available_indices = range(obstacle_scenes.size())

	# 실제로 obstacle_scenes에 존재하는 인덱스만 필터링
	var valid_indices: Array = []
	for idx in available_indices:
		if idx >= 0 and idx < obstacle_scenes.size() and obstacle_scenes[idx] != null:
			valid_indices.append(idx)

	if valid_indices.is_empty():
		push_warning("ObstacleSpawner: 유효한 장애물 씬이 없습니다.")
		return

	# 랜덤 장애물 선택
	var scene_index: int = valid_indices[randi() % valid_indices.size()]
	var obstacle_scene: PackedScene = obstacle_scenes[scene_index]

	# 스폰 위치와 기본 방향 결정
	var spawn_side: SpawnSide = _get_random_side()
	var spawn_position: Vector2 = _calculate_spawn_position(spawn_side)
	var base_direction: Vector2 = _get_base_direction(spawn_side)

	# 플레이어 방향 에이밍 적용
	var final_direction: Vector2 = _apply_aim(spawn_position, base_direction)

	# 속도 배율 적용
	var speed_multiplier: float = 1.0
	if difficulty_manager:
		speed_multiplier = difficulty_manager.get_speed_multiplier()

	# 장애물 인스턴스 생성
	var obstacle: Node2D = obstacle_scene.instantiate()
	obstacle.position = spawn_position

	# 장애물에 이동 데이터 전달
	# 장애물 씬은 direction, speed 프로퍼티를 가져야 한다.
	if obstacle.has_method("initialize"):
		obstacle.initialize(final_direction, base_speed * speed_multiplier)
	else:
		# initialize 메서드가 없으면 프로퍼티에 직접 설정 시도
		if "direction" in obstacle:
			obstacle.direction = final_direction
		if "speed" in obstacle:
			obstacle.speed = base_speed * speed_multiplier

	# 충돌 관리자가 있으면 장애물의 body_entered 시그널 연결
	if collision_handler and obstacle is Area2D:
		obstacle.body_entered.connect(collision_handler.on_obstacle_body_entered)

	obstacle_container.add_child(obstacle)


# 4면 중 랜덤으로 하나를 선택한다.
func _get_random_side() -> SpawnSide:
	return randi() % 4 as SpawnSide


# 스폰 면에 따른 스폰 위치를 계산한다.
# 각 면의 범위 내에서 랜덤 좌표를 생성.
func _calculate_spawn_position(side: SpawnSide) -> Vector2:
	match side:
		SpawnSide.TOP:
			return Vector2(randf_range(0.0, _viewport_size.x), -spawn_offset)
		SpawnSide.BOTTOM:
			return Vector2(randf_range(0.0, _viewport_size.x), _viewport_size.y + spawn_offset)
		SpawnSide.LEFT:
			return Vector2(-spawn_offset, randf_range(0.0, _viewport_size.y))
		SpawnSide.RIGHT:
			return Vector2(_viewport_size.x + spawn_offset, randf_range(0.0, _viewport_size.y))
		_:
			return Vector2.ZERO


# 스폰 면에 대응하는 기본 이동 방향을 반환한다.
func _get_base_direction(side: SpawnSide) -> Vector2:
	match side:
		SpawnSide.TOP:
			return Vector2.DOWN
		SpawnSide.BOTTOM:
			return Vector2.UP
		SpawnSide.LEFT:
			return Vector2.RIGHT
		SpawnSide.RIGHT:
			return Vector2.LEFT
		_:
			return Vector2.DOWN


# 플레이어 방향 에이밍을 적용한다.
# aim_strength가 0이면 기본 방향 그대로, 1이면 플레이어 직행.
# 중간 값이면 기본 방향과 플레이어 방향을 보간한다.
func _apply_aim(spawn_pos: Vector2, base_dir: Vector2) -> Vector2:
	if not player_target or aim_strength <= 0.0:
		return base_dir

	var to_player: Vector2 = (player_target.global_position - spawn_pos).normalized()

	# 기본 방향과 플레이어 방향을 aim_strength 비율로 보간
	var aimed_direction: Vector2 = base_dir.lerp(to_player, aim_strength).normalized()
	return aimed_direction
