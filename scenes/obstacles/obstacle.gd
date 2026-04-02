class_name Obstacle
extends Area2D
## 기본 장애물 스크립트.
## 지정된 방향과 속도로 직선 이동하며, 플레이어(CharacterBody2D)와
## 충돌하면 hit 시그널을 발생시킨다. 화면 밖으로 벗어나면 자동 해제.

## 플레이어와 충돌했을 때 발생하는 시그널
signal hit

## 이동 속도 (pixels/sec)
@export var speed: float = 200.0

## 이동 방향 (정규화 권장)
@export var direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	# body_entered 시그널을 연결하여 CharacterBody2D 감지
	body_entered.connect(_on_body_entered)

	# VisibleOnScreenNotifier2D 가 화면 밖으로 나갈 때 자동 해제
	var notifier := $VisibleOnScreenNotifier2D as VisibleOnScreenNotifier2D
	notifier.screen_exited.connect(_on_screen_exited)


func _process(delta: float) -> void:
	position += direction * speed * delta


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		hit.emit()


func _on_screen_exited() -> void:
	queue_free()
