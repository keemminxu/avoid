extends CharacterBody2D
## 플레이어 캐릭터
## 방향키로 8방향 이동, 화면 밖으로 나가지 않도록 클램핑

# 이동 속도 (에디터에서 조정 가능)
@export var speed: float = 300.0

# 플레이어 사망 시그널
signal player_died

# 뷰포트 크기 캐싱
var _viewport_size: Vector2 = Vector2.ZERO
# 충돌 반지름 (클램핑 계산용)
var _collision_radius: float = 16.0


func _ready() -> void:
	_viewport_size = get_viewport_rect().size


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

	# 화면 밖으로 나가지 않도록 위치 클램핑
	_clamp_to_viewport()


func _clamp_to_viewport() -> void:
	## 뷰포트 경계 안에 플레이어 위치를 제한
	var pos := global_position
	pos.x = clampf(pos.x, _collision_radius, _viewport_size.x - _collision_radius)
	pos.y = clampf(pos.y, _collision_radius, _viewport_size.y - _collision_radius)
	global_position = pos


func die() -> void:
	## 플레이어 사망 처리
	player_died.emit()
	set_physics_process(false)
