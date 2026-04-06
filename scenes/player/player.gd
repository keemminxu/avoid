extends CharacterBody2D
## 플레이어 캐릭터
## 방향키로 8방향 이동, 원형 경기장 안에서만 이동 가능

# 이동 속도 (에디터에서 조정 가능)
@export var speed: float = 300.0

# 플레이어 사망 시그널
signal player_died

# 원형 경기장 파라미터
const ARENA_CENTER: Vector2 = Vector2(640, 360)
const ARENA_RADIUS: float = 320.0

# 충돌 반지름 (원형 비주얼과 동일)
var _collision_radius: float = 8.0


func _ready() -> void:
	# 시작 위치를 경기장 중앙으로 설정
	global_position = ARENA_CENTER


func _physics_process(_delta: float) -> void:
	# 입력 방향 계산
	var input_direction := Vector2.ZERO
	input_direction.x = Input.get_axis("move_left", "move_right")
	input_direction.y = Input.get_axis("move_up", "move_down")

	# 대각선 이동 시 정규화하여 속도 일정하게 유지
	if input_direction.length() > 0.0:
		input_direction = input_direction.normalized()

	# 속도 설정 및 이동
	velocity = input_direction * speed
	move_and_slide()

	# 원형 경계 안에 플레이어 위치를 제한
	_clamp_to_arena()


func _draw() -> void:
	# 흰색 원으로 플레이어 비주얼 표현
	draw_circle(Vector2.ZERO, _collision_radius, Color.WHITE)


func _clamp_to_arena() -> void:
	## 원형 경기장 경계 안에 플레이어 위치를 제한
	var offset: Vector2 = global_position - ARENA_CENTER
	var max_distance: float = ARENA_RADIUS - _collision_radius
	if offset.length() > max_distance:
		global_position = ARENA_CENTER + offset.normalized() * max_distance


func die() -> void:
	## 플레이어 사망 처리
	player_died.emit()
	set_physics_process(false)
