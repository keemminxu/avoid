# Database Schema Design

죽림고수(Avoid) 게임의 데이터베이스 스키마 설계 문서.

## 테이블 구조

### players

플레이어 기본 정보를 저장하는 테이블.

| 컬럼 | 타입 | 제약 조건 | 설명 |
|------|------|----------|------|
| id | UUID | PK | 고유 식별자 |
| nickname | VARCHAR(20) | UNIQUE, NOT NULL | 플레이어 닉네임 |
| created_at | TIMESTAMP | NOT NULL, DEFAULT NOW() | 계정 생성 시각 |
| last_played_at | TIMESTAMP | NULL | 마지막 플레이 시각 |
| total_games | INT | NOT NULL, DEFAULT 0 | 총 플레이 횟수 |

```sql
CREATE TABLE players (
	id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
	nickname VARCHAR(20) UNIQUE NOT NULL,
	created_at TIMESTAMP NOT NULL DEFAULT NOW(),
	last_played_at TIMESTAMP,
	total_games INT NOT NULL DEFAULT 0,

	CONSTRAINT chk_nickname_length CHECK (char_length(nickname) >= 2),
	CONSTRAINT chk_total_games_non_negative CHECK (total_games >= 0)
);
```

### scores

개별 게임 기록을 저장하는 테이블. 한 플레이어가 여러 기록을 가질 수 있다 (1:N).

| 컬럼 | 타입 | 제약 조건 | 설명 |
|------|------|----------|------|
| id | UUID | PK | 고유 식별자 |
| player_id | UUID | FK -> players.id, NOT NULL | 플레이어 참조 |
| score | INT | NOT NULL | 획득 점수 |
| survival_time_sec | FLOAT | NOT NULL | 생존 시간 (초) |
| max_difficulty_level | INT | NULL | 도달한 최고 난이도 레벨 |
| played_at | TIMESTAMP | NOT NULL, DEFAULT NOW() | 플레이 시각 |
| server_region | VARCHAR(10) | NULL | 서버 리전 (kr, jp, us-west 등) |

```sql
CREATE TABLE scores (
	id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
	player_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
	score INT NOT NULL,
	survival_time_sec FLOAT NOT NULL,
	max_difficulty_level INT,
	played_at TIMESTAMP NOT NULL DEFAULT NOW(),
	server_region VARCHAR(10),

	CONSTRAINT chk_score_non_negative CHECK (score >= 0),
	CONSTRAINT chk_survival_time_positive CHECK (survival_time_sec > 0),
	CONSTRAINT chk_difficulty_positive CHECK (max_difficulty_level IS NULL OR max_difficulty_level > 0),
	CONSTRAINT chk_server_region_format CHECK (server_region IS NULL OR server_region ~ '^[a-z]{2}(-[a-z]+)?$')
);
```

### rankings (뷰)

랭킹은 실시간 뷰로 구성한다. 트래픽이 증가하면 Materialized View 또는 캐시 테이블로 전환할 수 있다.

#### 전체 랭킹 뷰

```sql
CREATE VIEW rankings_all AS
SELECT
	p.id AS player_id,
	p.nickname,
	MAX(s.score) AS best_score,
	MAX(s.survival_time_sec) AS best_survival_time,
	RANK() OVER (ORDER BY MAX(s.score) DESC) AS rank
FROM players p
INNER JOIN scores s ON s.player_id = p.id
GROUP BY p.id, p.nickname
ORDER BY rank;
```

#### 일간 랭킹 뷰

```sql
CREATE VIEW rankings_daily AS
SELECT
	p.id AS player_id,
	p.nickname,
	MAX(s.score) AS best_score,
	MAX(s.survival_time_sec) AS best_survival_time,
	RANK() OVER (ORDER BY MAX(s.score) DESC) AS rank
FROM players p
INNER JOIN scores s ON s.player_id = p.id
WHERE s.played_at >= CURRENT_DATE
GROUP BY p.id, p.nickname
ORDER BY rank;
```

#### 주간 랭킹 뷰

```sql
CREATE VIEW rankings_weekly AS
SELECT
	p.id AS player_id,
	p.nickname,
	MAX(s.score) AS best_score,
	MAX(s.survival_time_sec) AS best_survival_time,
	RANK() OVER (ORDER BY MAX(s.score) DESC) AS rank
FROM players p
INNER JOIN scores s ON s.player_id = p.id
WHERE s.played_at >= date_trunc('week', CURRENT_DATE)
GROUP BY p.id, p.nickname
ORDER BY rank;
```

#### 캐시 테이블 (고트래픽 대비)

트래픽이 증가하여 뷰 성능이 부족할 경우, 주기적으로 갱신되는 캐시 테이블로 전환한다.

```sql
CREATE TABLE rankings_cache (
	player_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
	nickname VARCHAR(20) NOT NULL,
	best_score INT NOT NULL,
	best_survival_time FLOAT NOT NULL,
	rank INT NOT NULL,
	period VARCHAR(10) NOT NULL, -- 'daily', 'weekly', 'all'
	updated_at TIMESTAMP NOT NULL DEFAULT NOW(),

	PRIMARY KEY (player_id, period)
);

CREATE INDEX idx_rankings_cache_period_rank ON rankings_cache(period, rank);
```

## 인덱스 전략

### players 테이블

```sql
-- nickname 검색 (로그인, 중복 확인)
-- UNIQUE 제약 조건이 자동으로 인덱스를 생성하므로 별도 인덱스 불필요

-- last_played_at 기준 비활성 계정 조회
CREATE INDEX idx_players_last_played ON players(last_played_at);
```

### scores 테이블

```sql
-- 특정 플레이어의 점수 조회 (최신순)
CREATE INDEX idx_scores_player_played ON scores(player_id, played_at DESC);

-- 랭킹 뷰 최적화: 점수 기준 정렬
CREATE INDEX idx_scores_score_desc ON scores(score DESC);

-- 일간/주간 랭킹 필터링: played_at 기준
CREATE INDEX idx_scores_played_at ON scores(played_at);

-- 리전별 조회
CREATE INDEX idx_scores_region ON scores(server_region) WHERE server_region IS NOT NULL;
```

## 주요 쿼리 예시

### 플레이어 등록

```sql
INSERT INTO players (nickname)
VALUES ('player_name')
RETURNING id, nickname, created_at;
```

### 점수 제출

트랜잭션으로 점수 저장과 플레이어 통계 업데이트를 원자적으로 처리한다.

```sql
BEGIN;

INSERT INTO scores (player_id, score, survival_time_sec, max_difficulty_level, server_region)
VALUES ($1, $2, $3, $4, $5);

UPDATE players
SET total_games = total_games + 1,
	last_played_at = NOW()
WHERE id = $1;

COMMIT;
```

### 전체 랭킹 조회 (상위 N명)

```sql
SELECT player_id, nickname, best_score, best_survival_time, rank
FROM rankings_all
WHERE rank <= $1
ORDER BY rank;
```

### 일간 랭킹 조회

```sql
SELECT player_id, nickname, best_score, best_survival_time, rank
FROM rankings_daily
WHERE rank <= $1
ORDER BY rank;
```

### 특정 플레이어의 최근 기록

```sql
SELECT score, survival_time_sec, max_difficulty_level, played_at, server_region
FROM scores
WHERE player_id = $1
ORDER BY played_at DESC
LIMIT $2;
```

### 특정 플레이어의 최고 점수

```sql
SELECT MAX(score) AS best_score, MAX(survival_time_sec) AS best_survival_time
FROM scores
WHERE player_id = $1;
```

## 데이터 무결성

- **외래 키**: scores.player_id -> players.id (CASCADE DELETE)
- **CHECK 제약**: 점수는 0 이상, 생존 시간은 양수, 닉네임은 2자 이상
- **트랜잭션**: 점수 제출 시 scores INSERT와 players UPDATE를 원자적 처리
- **UNIQUE**: nickname 중복 방지

## 확장 고려사항

- **파티셔닝**: scores 테이블이 커지면 played_at 기준 월별 파티셔닝 적용
- **Materialized View**: 랭킹 뷰를 Materialized View로 전환하고 주기적 REFRESH (1분~5분 간격)
- **읽기 복제본**: 랭킹 조회는 읽기 복제본으로 분산
- **TTL**: 오래된 scores 레코드 자동 아카이빙 정책 (예: 1년 이상 된 기록)
