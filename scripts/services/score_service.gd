class_name ScoreService
extends Node

## 점수 및 랭킹 서비스.
## 서버 통신을 추상화하며, 서버 연결 실패 시 로컬 저장소로 자동 전환한다.

## 점수 제출 완료 시 발생한다. success가 false이면 서버 실패 후 로컬 저장 결과를 나타낸다.
signal score_submitted(success: bool)

## 리더보드 로드 완료 시 발생한다. data는 랭킹 항목 배열이다.
signal leaderboard_loaded(data: Array)

## 플레이어 등록 완료 시 발생한다. player_id는 등록된 플레이어 ID (실패 시 빈 문자열).
signal player_registered(player_id: String)

## 서버 기본 URL. 서버 구축 후 실제 주소로 변경한다.
@export var base_url: String = "http://localhost:8080/api"

## 서버 요청 타임아웃 (초).
@export var request_timeout: float = 10.0

## 현재 서버 연결 가능 여부.
var is_online: bool = false

## 로컬 스코어 저장소 인스턴스.
var _local_storage: LocalScoreStorage

## HTTP 요청에 사용할 노드. 요청마다 새로 생성한다.
## _active_requests로 활성 요청을 추적한다.
var _active_requests: Array[HTTPRequest] = []

## 요청 종류를 식별하기 위한 메타 키.
const META_REQUEST_TYPE: String = "request_type"
const META_REQUEST_CONTEXT: String = "request_context"


func _ready() -> void:
	_local_storage = LocalScoreStorage.new()
	_check_server_connection()


## 서버에 점수를 제출한다.
## 서버 연결 실패 시 로컬 저장소에 저장한다.
func submit_score(player_id: String, score: int, survival_time: float, difficulty: int) -> void:
	var payload: Dictionary = {
		"player_id": player_id,
		"score": score,
		"survival_time_sec": survival_time,
		"max_difficulty_level": difficulty,
	}

	if is_online:
		var context: Dictionary = {
			"score": score,
			"survival_time": survival_time,
			"difficulty": difficulty,
		}
		_send_request(
			"/scores",
			HTTPClient.METHOD_POST,
			payload,
			"submit_score",
			context
		)
	else:
		_save_score_locally(score, survival_time, difficulty)
		score_submitted.emit(true)


## 리더보드를 조회한다.
## period: "daily", "weekly", "all"
func get_leaderboard(period: String = "all", limit: int = 10) -> void:
	if is_online:
		var context: Dictionary = {
			"period": period,
			"limit": limit,
		}
		_send_request(
			"/leaderboard?period=%s&limit=%d" % [period, limit],
			HTTPClient.METHOD_GET,
			{},
			"get_leaderboard",
			context
		)
	else:
		var local_data: Array = _local_storage.get_leaderboard(limit)
		leaderboard_loaded.emit(local_data)


## 새 플레이어를 등록한다.
func register_player(nickname: String) -> void:
	var payload: Dictionary = {
		"nickname": nickname,
	}

	if is_online:
		_send_request(
			"/players",
			HTTPClient.METHOD_POST,
			payload,
			"register_player",
			{}
		)
	else:
		# 오프라인에서는 로컬 UUID를 생성하여 반환한다
		var local_id: String = _generate_local_uuid()
		player_registered.emit(local_id)


## 서버 연결 상태를 확인한다.
func _check_server_connection() -> void:
	_send_request(
		"/health",
		HTTPClient.METHOD_GET,
		{},
		"health_check",
		{}
	)


## HTTP 요청을 전송한다.
func _send_request(
	endpoint: String,
	method: HTTPClient.Method,
	payload: Dictionary,
	request_type: String,
	context: Dictionary
) -> void:
	var http_request: HTTPRequest = HTTPRequest.new()
	http_request.timeout = request_timeout
	add_child(http_request)
	_active_requests.append(http_request)

	http_request.set_meta(META_REQUEST_TYPE, request_type)
	http_request.set_meta(META_REQUEST_CONTEXT, context)
	http_request.request_completed.connect(_on_request_completed.bind(http_request))

	var url: String = base_url + endpoint
	var headers: PackedStringArray = PackedStringArray(["Content-Type: application/json"])

	var error: Error
	if method == HTTPClient.METHOD_GET:
		error = http_request.request(url, headers, method)
	else:
		var body: String = JSON.stringify(payload)
		error = http_request.request(url, headers, method, body)

	if error != OK:
		push_warning("ScoreService: HTTP 요청 실패 - %s" % error_string(error))
		_handle_request_failure(http_request)


## HTTP 응답 처리 콜백.
func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	http_request: HTTPRequest
) -> void:
	var request_type: String = http_request.get_meta(META_REQUEST_TYPE, "") as String
	var context: Dictionary = http_request.get_meta(META_REQUEST_CONTEXT, {}) as Dictionary

	# 요청 노드 정리
	_cleanup_request(http_request)

	# 네트워크 오류 처리
	if result != HTTPRequest.RESULT_SUCCESS:
		push_warning("ScoreService: 네트워크 오류 (result=%d, type=%s)" % [result, request_type])
		_handle_failure_by_type(request_type, context)
		return

	# HTTP 상태 코드 검사
	if response_code < 200 or response_code >= 300:
		push_warning("ScoreService: 서버 오류 (code=%d, type=%s)" % [response_code, request_type])
		_handle_failure_by_type(request_type, context)
		return

	# 응답 본문 파싱
	var response_text: String = body.get_string_from_utf8()
	var response_data: Variant = _parse_json_response(response_text)

	# 요청 종류별 성공 처리
	match request_type:
		"health_check":
			is_online = true
		"submit_score":
			score_submitted.emit(true)
		"get_leaderboard":
			var entries: Array = []
			if response_data is Array:
				entries = response_data as Array
			leaderboard_loaded.emit(entries)
		"register_player":
			var player_id: String = ""
			if response_data is Dictionary:
				player_id = (response_data as Dictionary).get("id", "") as String
			player_registered.emit(player_id)


## 요청 실패 시 타입별 폴백 처리.
func _handle_failure_by_type(request_type: String, context: Dictionary) -> void:
	is_online = false
	match request_type:
		"health_check":
			is_online = false
		"submit_score":
			var score: int = context.get("score", 0) as int
			var survival_time: float = context.get("survival_time", 0.0) as float
			var difficulty: int = context.get("difficulty", 0) as int
			_save_score_locally(score, survival_time, difficulty)
			score_submitted.emit(true)
		"get_leaderboard":
			var limit: int = context.get("limit", 10) as int
			var local_data: Array = _local_storage.get_leaderboard(limit)
			leaderboard_loaded.emit(local_data)
		"register_player":
			var local_id: String = _generate_local_uuid()
			player_registered.emit(local_id)


## 요청 노드 정리 (공통 로직 분리).
func _handle_request_failure(http_request: HTTPRequest) -> void:
	var request_type: String = http_request.get_meta(META_REQUEST_TYPE, "") as String
	var context: Dictionary = http_request.get_meta(META_REQUEST_CONTEXT, {}) as Dictionary
	_cleanup_request(http_request)
	_handle_failure_by_type(request_type, context)


## HTTPRequest 노드를 제거하고 추적 목록에서 삭제한다.
func _cleanup_request(http_request: HTTPRequest) -> void:
	var idx: int = _active_requests.find(http_request)
	if idx >= 0:
		_active_requests.remove_at(idx)
	if http_request.is_inside_tree():
		http_request.queue_free()


## 로컬 저장소에 점수를 저장한다.
func _save_score_locally(score: int, survival_time: float, difficulty: int) -> void:
	_local_storage.save_score(score, survival_time, difficulty)


## JSON 문자열을 파싱한다. 실패 시 null을 반환한다.
func _parse_json_response(text: String) -> Variant:
	if text.is_empty():
		return null
	var json: JSON = JSON.new()
	var error: Error = json.parse(text)
	if error != OK:
		push_warning("ScoreService: JSON 파싱 실패 - %s" % json.get_error_message())
		return null
	return json.data


## 로컬 UUID를 생성한다.
## 서버 미연결 시 임시 플레이어 식별에 사용한다.
func _generate_local_uuid() -> String:
	# Godot 내장 유틸리티로 간이 UUID를 생성한다
	var bytes: PackedByteArray = Crypto.new().generate_random_bytes(16)
	# UUID v4 형식으로 변환
	bytes[6] = (bytes[6] & 0x0f) | 0x40  # 버전 4
	bytes[8] = (bytes[8] & 0x3f) | 0x80  # variant 1
	var hex: String = bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [
		hex.substr(0, 8),
		hex.substr(8, 4),
		hex.substr(12, 4),
		hex.substr(16, 4),
		hex.substr(20, 12),
	]


## 노드 제거 시 활성 요청을 정리한다.
func _exit_tree() -> void:
	for req: HTTPRequest in _active_requests:
		if is_instance_valid(req) and req.is_inside_tree():
			req.queue_free()
	_active_requests.clear()
