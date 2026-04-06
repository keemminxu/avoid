class_name ObstacleSpawner
extends Node2D

## 장애물 스포너 (원형 경기장 버전)
## 원형 경기장 가장자리에서 장애물을 스폰하고, 오브젝트 풀을 통해 재사용한다.
## DifficultyManager와 연동하여 웨이브 단위로 다량 동시 스폰.

# 경기장 상수
const ARENA_CENTER := Vector2(640.0, 360.0)
const ARENA_RADIUS := 320.0
# 스폰 거리: 경기장 반지름 + 오프셋 (화면 밖에서 스폰)
const SPAWN_DISTANCE_OFFSET := 50.0
# 이동 방향 랜덤 오프셋 (라디안) — 중심을 향하되 ±30도 흔들림
const DIRECTION_JITTER_RAD := deg_to_rad(30.0)

# 오브젝트 풀 참조 (에너미 종류별 풀 4개)
# [0]=일반, [1]=고속, [2]=대형, [3]=추적
@export var pools: Array[ObjectPool] = []

# 난이도 관리자 참조
@export var difficulty_manager: DifficultyManager

# 플레이어 참조 (추적 화살용)
@export var player_target: Node2D

# 충돌 핸들러 참조
@export var collision_handler: CollisionHandler

# 스폰된 장애물이 추가될 부모 노드
@export var obstacle_container: Node2D

# 장애물 기본 이동 속도 (px/sec)
@export var base_speed: float = 200.0

# 기본 스폰 간격 (초). DifficultyManager가 없을 때 사용.
@export var spawn_interval: float = 1.0

# 내부 스폰 타이머
var _spawn_timer: Timer

# body_entered 시그널이 이미 연결된 인스턴스를 추적
var _connected_instances: Dictionary = {}

# exited_arena 시그널이 이미 연결된 인스턴스를 추적
var _exit_connected_instances: Dictionary = {}

# 인스턴스 → 풀 매핑 (반환 시 어느 풀로 돌려보낼지)
var _instance_pool_map: Dictionary = {}


func _ready() -> void:
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


# 스폰 타이머가 만료될 때마다 호출. 웨이브 단위로 장애물을 스폰한다.
func _on_spawn_timer_timeout() -> void:
	_spawn_wave()


# 한 웨이브의 장애물을 스폰한다.
# DifficultyManager에서 스폰 개수를 받아 한번에 그만큼 스폰.
func _spawn_wave() -> void:
	if pools.is_empty():
		push_warning("ObstacleSpawner: pools 배열이 비어있습니다.")
		return

	if not obstacle_container:
		push_warning("ObstacleSpawner: obstacle_container가 설정되지 않았습니다.")
		return

	# 스폰 개수 결정
	var spawn_count: int = 1
	if difficulty_manager:
		spawn_count = difficulty_manager.get_spawn_count()

	# 사용 가능한 장애물 종류 인덱스 결정
	var available_indices: Array
	if difficulty_manager:
		available_indices = difficulty_manager.get_available_obstacles()
	else:
		available_indices = range(pools.size())

	# 실제로 pools에 존재하는 인덱스만 필터링
	var valid_indices: Array = []
	for idx in available_indices:
		if idx >= 0 and idx < pools.size() and pools[idx] != null:
			valid_indices.append(idx)

	if valid_indices.is_empty():
		push_warning("ObstacleSpawner: 유효한 풀이 없습니다.")
		return

	# 속도 배율
	var speed_multiplier: float = 1.0
	if difficulty_manager:
		speed_multiplier = difficulty_manager.get_speed_multiplier()

	# 각 장애물을 독립적으로 스폰
	for i in spawn_count:
		_spawn_single_obstacle(valid_indices, speed_multiplier)


# 장애물 하나를 원형 가장자리에서 스폰한다.
func _spawn_single_obstacle(valid_indices: Array, speed_multiplier: float) -> void:
	# 랜덤 장애물 종류 선택
	var pool_index: int = valid_indices[randi() % valid_indices.size()]

	# 추적 타입(인덱스 3) 여부
	var is_tracking: bool = (pool_index == 3)

	# 오브젝트 풀에서 인스턴스 획득
	var pool: ObjectPool = pools[pool_index]
	var obstacle: Node2D = pool.get_object()
	if not obstacle:
		return

	# 원형 가장자리 스폰 위치 계산
	var spawn_angle: float = randf() * TAU
	var spawn_distance: float = ARENA_RADIUS + SPAWN_DISTANCE_OFFSET
	var spawn_position: Vector2 = ARENA_CENTER + Vector2.from_angle(spawn_angle) * spawn_distance

	# 이동 방향 계산
	var final_direction: Vector2
	if is_tracking and player_target:
		# 추적 화살: 플레이어 방향으로 직행
		final_direction = (player_target.global_position - spawn_position).normalized()
	else:
		# 일반 화살: 원 중심 방향 + 랜덤 오프셋 (±30도)
		var to_center: Vector2 = (ARENA_CENTER - spawn_position).normalized()
		var jitter: float = randf_range(-DIRECTION_JITTER_RAD, DIRECTION_JITTER_RAD)
		final_direction = to_center.rotated(jitter)

	# 위치 설정
	obstacle.position = spawn_position

	# 장애물 초기화 (direction, speed 설정)
	var final_speed: float = base_speed * speed_multiplier
	if obstacle.has_method("initialize"):
		obstacle.initialize(final_direction, final_speed)
	else:
		if "direction" in obstacle:
			obstacle.direction = final_direction
		if "speed" in obstacle:
			obstacle.speed = final_speed

	# 인스턴스 → 풀 매핑 갱신 (매 스폰 시 최신 풀 참조 유지)
	var instance_id: int = obstacle.get_instance_id()
	_instance_pool_map[instance_id] = pool

	# exited_arena 시그널 연결 (최초 1회만)
	if obstacle.has_signal("exited_arena"):
		if not _exit_connected_instances.has(instance_id):
			obstacle.exited_arena.connect(_on_obstacle_exited_arena)
			_exit_connected_instances[instance_id] = true

	# 충돌 핸들러 연결 (최초 1회만)
	if collision_handler and obstacle is Area2D:
		if not _connected_instances.has(instance_id):
			obstacle.body_entered.connect(collision_handler.on_obstacle_body_entered)
			_connected_instances[instance_id] = true

	# 컨테이너에 추가 (이미 자식이 아닌 경우에만)
	if obstacle.get_parent() != obstacle_container:
		obstacle_container.add_child(obstacle)


# 장애물이 경기장 밖으로 나갔을 때 풀에 반환한다.
func _on_obstacle_exited_arena(obstacle: Node2D) -> void:
	var instance_id: int = obstacle.get_instance_id()
	var pool: ObjectPool = _instance_pool_map.get(instance_id) as ObjectPool
	if not pool:
		push_warning("ObstacleSpawner: 풀 매핑을 찾을 수 없습니다 (instance_id=%d)." % instance_id)
		return

	# 상태 리셋
	if obstacle.has_method("reset"):
		obstacle.reset()

	pool.release(obstacle)
