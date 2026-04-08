extends CharacterBody2D
## 플레이어 캐릭터
## 방향키로 8방향 이동, 원형 경기장 안에서만 이동 가능.
## 비주얼은 GameData.selected_character에 따라 $Sprite에 동적으로 로드된다.

# 이동 속도 (에디터에서 조정 가능)
@export var speed: float = 300.0

# 플레이어 사망 시그널
signal player_died

# 원형 경기장 파라미터
const ARENA_CENTER: Vector2 = Vector2(640, 360)
const ARENA_RADIUS: float = 320.0

# 충돌 반지름
var _collision_radius: float = 8.0

# 스프라이트의 원본 이미지가 화면에 표시될 최대 변 길이 (px)
const SPRITE_TARGET_SIZE: float = 56.0

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	# 시작 위치를 경기장 중앙으로 설정
	global_position = ARENA_CENTER
	_load_character_sprite()


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


func _load_character_sprite() -> void:
	## GameData에서 선택된 캐릭터 텍스처를 로드하고 SPRITE_TARGET_SIZE 에 맞게 스케일한다.
	## 이미지 원본 해상도는 사진 원본(1000px+)이라 런타임 계산으로 적절한 크기를 맞춘다.
	var tex_path := GameData.get_character_texture_path()
	var texture := load(tex_path) as Texture2D
	if texture == null:
		push_warning("Player: 캐릭터 텍스처 로드 실패 - %s" % tex_path)
		return

	_sprite.texture = texture
	var tex_size: Vector2 = texture.get_size()
	var max_dim: float = maxf(tex_size.x, tex_size.y)
	if max_dim > 0.0:
		var factor: float = SPRITE_TARGET_SIZE / max_dim
		_sprite.scale = Vector2(factor, factor)
