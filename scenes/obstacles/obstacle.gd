class_name Obstacle
extends Area2D

## 기본 장애물 (에너미 함선)
## 지정된 방향과 속도로 직선 이동하며, 자식 Sprite2D 가 비주얼을 담당한다.
## 이동 방향을 향해 회전하며, 원형 경기장 밖으로 벗어나면 exited_arena 시그널을 발생시킨다.
## 오브젝트 풀과 호환되는 initialize/reset 메서드를 제공한다.

## 경기장 밖으로 벗어났을 때 발생하는 시그널 (풀 반환용).
## 어느 인스턴스가 나갔는지 스포너 쪽 핸들러가 식별할 수 있도록 self를 함께 보낸다.
signal exited_arena(obstacle: Node2D)

## 플레이어와 충돌했을 때 발생하는 시그널
signal hit

## 이동 속도 (pixels/sec)
@export var speed: float = 200.0

## 이동 방향 (정규화 권장)
@export var direction: Vector2 = Vector2.RIGHT

## 스프라이트 회전 오프셋 (라디안)
## Kenney 함선은 기본적으로 위쪽을 향해 그려져 있어 이동 방향 대비 +90도 보정이 필요하다.
## 변종마다 다를 수 있으므로 자식 클래스가 오버라이드할 수 있다.
var sprite_rotation_offset: float = PI * 0.5

## 경기장 중심 좌표
const ARENA_CENTER := Vector2(640, 360)

## 경기장 반지름
const ARENA_RADIUS: float = 320.0

## 경기장 밖 판정 여유 거리 (px)
const EXIT_MARGIN: float = 200.0


func _ready() -> void:
	rotation = direction.angle() + sprite_rotation_offset


func _process(delta: float) -> void:
	position += direction * speed * delta

	# 경기장 중심에서의 거리로 탈출 판정
	var distance_from_center := position.distance_to(ARENA_CENTER)
	if distance_from_center > ARENA_RADIUS + EXIT_MARGIN:
		exited_arena.emit(self)


## 풀에서 꺼낼 때 방향과 속도를 설정한다.
func initialize(dir: Vector2, spd: float) -> void:
	direction = dir.normalized()
	speed = spd
	rotation = direction.angle() + sprite_rotation_offset


## 풀에 반환하기 전 상태를 초기화한다.
func reset() -> void:
	direction = Vector2.RIGHT
	speed = 200.0
	rotation = 0.0
	position = Vector2(-9999, -9999)
