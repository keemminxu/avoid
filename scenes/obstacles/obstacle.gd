class_name Obstacle
extends Area2D

## 기본 장애물 (화살 형태)
## 지정된 방향과 속도로 직선 이동하며, _draw()로 얇고 긴 막대기를 렌더링한다.
## 이동 방향을 향해 회전하며, 원형 경기장 밖으로 벗어나면 exited_arena 시그널을 발생시킨다.
## 오브젝트 풀과 호환되는 initialize/reset 메서드를 제공한다.

## 경기장 밖으로 벗어났을 때 발생하는 시그널 (풀 반환용)
signal exited_arena

## 플레이어와 충돌했을 때 발생하는 시그널
signal hit

## 이동 속도 (pixels/sec)
@export var speed: float = 200.0

## 이동 방향 (정규화 권장)
@export var direction: Vector2 = Vector2.RIGHT

## 화살 길이 (px)
var arrow_length: float = 40.0

## 화살 너비 (px)
var arrow_width: float = 4.0

## 화살 색상
var arrow_color: Color = Color.WHITE

## 경기장 중심 좌표
const ARENA_CENTER := Vector2(640, 360)

## 경기장 반지름
const ARENA_RADIUS: float = 320.0

## 경기장 밖 판정 여유 거리 (px)
const EXIT_MARGIN: float = 200.0


func _ready() -> void:
	rotation = direction.angle()


func _draw() -> void:
	var half_length := arrow_length * 0.5
	var half_width := arrow_width * 0.5
	draw_rect(Rect2(-half_length, -half_width, arrow_length, arrow_width), arrow_color)


func _process(delta: float) -> void:
	position += direction * speed * delta

	# 경기장 중심에서의 거리로 탈출 판정
	var distance_from_center := position.distance_to(ARENA_CENTER)
	if distance_from_center > ARENA_RADIUS + EXIT_MARGIN:
		exited_arena.emit()


## 풀에서 꺼낼 때 방향과 속도를 설정한다.
func initialize(dir: Vector2, spd: float) -> void:
	direction = dir.normalized()
	speed = spd
	rotation = direction.angle()
	queue_redraw()


## 풀에 반환하기 전 상태를 초기화한다.
func reset() -> void:
	direction = Vector2.RIGHT
	speed = 200.0
	rotation = 0.0
	position = Vector2(-9999, -9999)
