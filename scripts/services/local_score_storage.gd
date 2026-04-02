class_name LocalScoreStorage
extends RefCounted

## 로컬 파일 시스템에 점수를 저장/로드하는 스토리지 클래스.
## user://scores.json 파일을 사용하여 오프라인 또는 서버 미연결 시 점수를 보관한다.

const SAVE_PATH: String = "user://scores.json"

## 점수 데이터를 가지고 있는 배열. 각 항목은 Dictionary.
var _scores: Array = []

## 초기화 시 기존 저장 파일을 로드한다.
func _init() -> void:
	_load_from_file()


## 점수를 저장한다.
## 메모리 배열에 추가하고 파일에 기록한다.
func save_score(score: int, survival_time: float, difficulty: int) -> void:
	var entry: Dictionary = {
		"score": score,
		"survival_time_sec": survival_time,
		"max_difficulty_level": difficulty,
		"played_at": Time.get_datetime_string_from_system(true),
	}
	_scores.append(entry)
	_save_to_file()


## 저장된 모든 점수를 최신순으로 반환한다.
func load_scores() -> Array:
	var sorted: Array = _scores.duplicate()
	sorted.sort_custom(_compare_by_date_desc)
	return sorted


## 최고 점수를 반환한다. 기록이 없으면 0을 반환한다.
func get_best_score() -> int:
	if _scores.is_empty():
		return 0
	var best: int = 0
	for entry: Dictionary in _scores:
		var s: int = entry.get("score", 0) as int
		if s > best:
			best = s
	return best


## 점수 기준 상위 N개의 리더보드를 반환한다.
func get_leaderboard(limit: int = 10) -> Array:
	var sorted: Array = _scores.duplicate()
	sorted.sort_custom(_compare_by_score_desc)
	if sorted.size() > limit:
		sorted.resize(limit)
	# 순위를 부여하여 반환한다
	var result: Array = []
	for i: int in range(sorted.size()):
		var entry: Dictionary = sorted[i].duplicate()
		entry["rank"] = i + 1
		result.append(entry)
	return result


## 저장된 점수 개수를 반환한다.
func get_score_count() -> int:
	return _scores.size()


## 모든 점수를 초기화한다.
func clear_scores() -> void:
	_scores.clear()
	_save_to_file()


## 파일에서 점수 데이터를 로드한다.
func _load_from_file() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_scores = []
		return

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("LocalScoreStorage: 점수 파일을 열 수 없음 - %s" % FileAccess.get_open_error())
		_scores = []
		return

	var content: String = file.get_as_text()
	file.close()

	if content.is_empty():
		_scores = []
		return

	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(content)
	if parse_result != OK:
		push_warning("LocalScoreStorage: JSON 파싱 실패 - %s" % json.get_error_message())
		_scores = []
		return

	var data: Variant = json.data
	if data is Array:
		_scores = data as Array
	else:
		push_warning("LocalScoreStorage: 잘못된 데이터 형식, 배열이 아님")
		_scores = []


## 현재 점수 데이터를 파일에 기록한다.
func _save_to_file() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("LocalScoreStorage: 점수 파일을 쓸 수 없음 - %s" % FileAccess.get_open_error())
		return

	var json_string: String = JSON.stringify(_scores, "\t")
	file.store_string(json_string)
	file.close()


## 날짜 내림차순 정렬용 비교 함수.
func _compare_by_date_desc(a: Dictionary, b: Dictionary) -> bool:
	var date_a: String = a.get("played_at", "") as String
	var date_b: String = b.get("played_at", "") as String
	return date_a > date_b


## 점수 내림차순 정렬용 비교 함수.
func _compare_by_score_desc(a: Dictionary, b: Dictionary) -> bool:
	var score_a: int = a.get("score", 0) as int
	var score_b: int = b.get("score", 0) as int
	return score_a > score_b
