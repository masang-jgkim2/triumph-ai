USE triumph;
-- ============================================================
-- unified_tournament_table_migration.sql
-- 기존 SE 스키마 → 통합 스키마 ALTER 마이그레이션
-- 실행 순서를 반드시 지켜야 합니다 (FK 의존성)
--
-- Windows에서 스크립트로 묶어 실행 시: 소스 파일 UTF-8로 읽기
--   PowerShell 예: Get-Content .\unified_tournament_table_migration.sql -Raw -Encoding utf8 | mysql ...
-- (기본 인코딩이면 한글 주석이 깨져 1064가 날 수 있음)
--
-- 통합 전·후 검증(건수·고아·이벤트별 비교): DDL 실행 전에
--   schema/unified_tournament_table_migration_verify.sql 의 PART A 결과를 저장한 뒤,
--   마이그레이션 완료 후 같은 파일의 PART B 및 V10 과 비교하세요.
-- ============================================================

SET FOREIGN_KEY_CHECKS = 0;

-- ============================================================
-- STEP 1. participants
-- 추가: checkin_status, final_rank
-- create_dt / update_dt 컬럼명 유지 (created_at·updated_at으로 변경하지 않음)
-- ============================================================
-- 1-1. 기존 컬럼 MODIFY
ALTER TABLE `participants`
    MODIFY COLUMN `participant_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    MODIFY COLUMN `dummy`          TINYINT(1)   NOT NULL DEFAULT 0;

-- 1-2. 신규 컬럼 ADD (재실행 1060 방지: 동적 SQL은 한 줄 SET만 사용 — MySQL은 ADD COLUMN IF NOT EXISTS 미지원)
SELECT COUNT(*) INTO @v_exist FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'participants' AND COLUMN_NAME = 'checkin_status';
SET @v_sql := IF(@v_exist = 0, 'ALTER TABLE participants ADD COLUMN checkin_status TINYINT(1) NOT NULL DEFAULT 0 AFTER entrant_image_url', 'SELECT 1');
PREPARE mstmt FROM @v_sql;
EXECUTE mstmt;
DEALLOCATE PREPARE mstmt;

SELECT COUNT(*) INTO @v_exist FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'participants' AND COLUMN_NAME = 'final_rank';
SET @v_sql := IF(@v_exist = 0, 'ALTER TABLE participants ADD COLUMN final_rank INT NULL DEFAULT NULL AFTER checkin_dt', 'SELECT 1');
PREPARE mstmt FROM @v_sql;
EXECUTE mstmt;
DEALLOCATE PREPARE mstmt;

-- 1-3. 타임스탬프 컬럼명: create_dt·update_dt 유지

-- 동적 ADD에는 COMMENT 미포함(IF 문자열 따옴표·쉼표 이슈 회피). COMMENT는 정적 MODIFY로 부여.
ALTER TABLE `participants`
    MODIFY COLUMN `checkin_status` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '0:미체크인, 1:체크인완료';
ALTER TABLE `participants`
    MODIFY COLUMN `final_rank` INT NULL DEFAULT NULL COMMENT '대회 최종 순위';

-- checkin_dt가 있으면 체크인 완료로 간주
UPDATE `participants` SET `checkin_status` = 1 WHERE `checkin_dt` IS NOT NULL;


-- ============================================================
-- STEP 2. participant_members
-- 추가: participant_member_id (PK AUTO_INCREMENT), role
-- create_dt / update_dt 유지
-- ============================================================
-- 2-1. PK 컬럼 + PRIMARY KEY 한 번에 (분리 시 MySQL: AUTO_INCREMENT 컬럼은 인덱스 필수 오류)
ALTER TABLE `participant_members`
    ADD COLUMN `participant_member_id` INT UNSIGNED NOT NULL AUTO_INCREMENT FIRST,
    ADD PRIMARY KEY (`participant_member_id`);

-- 2-2. 신규 컬럼 ADD
ALTER TABLE `participant_members`
    ADD COLUMN `role` ENUM('LEADER','MEMBER') NOT NULL DEFAULT 'MEMBER'
        AFTER `member_image_url`;

-- 2-3. 타임스탬프 컬럼명 유지 (create_dt·update_dt)


-- ============================================================
-- STEP 2b. bracket_groups 누락 보강 (레거시 데이터 정합성)
-- brackets 에만 존재하고 bracket_groups 에 없는 (event_id, depth) 조합을 INSERT
-- 목적: 4-2 group_id 매핑 실패·고아 brackets 삭제·통합 조회 0건 방지 (예: QA event_id 1033)
-- 전제: bracket_groups 가 아직 레거시 컬럼만 있고 group_id 컬럼 추가 전(STEP 3 이전)
-- 이후 STEP 3-4 에서 bracket_type 은 NOT NULL DEFAULT 'SE' 로 부여됨(DE/FFA 전용 이벤트는 별도 보정 필요할 수 있음)
-- ============================================================
INSERT INTO `bracket_groups` (`event_id`, `depth`, `start_dt`, `auto_judge`, `created_dt`, `updated_dt`)
SELECT DISTINCT
    b.`event_id`,
    b.`depth`,
    NULL       AS `start_dt`,
    0          AS `auto_judge`,
    NOW()      AS `created_dt`,
    NULL       AS `updated_dt`
FROM `brackets` b
WHERE NOT EXISTS (
    SELECT 1
    FROM `bracket_groups` bg
    WHERE bg.`event_id` = b.`event_id`
      AND bg.`depth`    = b.`depth`
);


-- ============================================================
-- STEP 3. bracket_groups  ← 핵심: PK 구조 변경
-- (event_id, depth) PK → group_id AUTO_INCREMENT PK
-- (event_id, depth) UNIQUE KEY 유지
-- 추가: bracket_type, title, round_count, advancement_strategy
-- ============================================================

-- 3-1. group_id 컬럼 추가 (DEFAULT 0 으로 우선 추가)
ALTER TABLE `bracket_groups`
    ADD COLUMN `group_id` INT UNSIGNED NOT NULL DEFAULT 0 FIRST;

-- 3-2. group_id 값 채우기 (event_id, depth 순 시퀀스)
SET @grp := 0;
UPDATE `bracket_groups`
SET `group_id` = (@grp := @grp + 1)
ORDER BY `event_id`, `depth`;

-- 3-3. PK 교체 (한 ALTER에 AUTO_INCREMENT까지 몰면 일부 MySQL에서 오류 → 단계 분리)
ALTER TABLE `bracket_groups`
    DROP PRIMARY KEY,
    ADD PRIMARY KEY (`group_id`);

ALTER TABLE `bracket_groups`
    MODIFY COLUMN `group_id` INT UNSIGNED NOT NULL AUTO_INCREMENT;

ALTER TABLE `bracket_groups`
    ADD UNIQUE KEY `uq_event_depth` (`event_id`, `depth`),
    ADD COLUMN `bracket_type` ENUM('SE','DE_WB','DE_LB','DE_GF','FFA')
        NOT NULL DEFAULT 'SE'
        COMMENT 'SE:싱글, DE_WB:더블승자조, DE_LB:패자조, DE_GF:결승, FFA:포인트제'
        AFTER `depth`,
    ADD COLUMN `title`                VARCHAR(100) NULL AFTER `bracket_type`,
    ADD COLUMN `round_count`          INT NOT NULL DEFAULT 1 AFTER `title`,
    ADD COLUMN `advancement_strategy` VARCHAR(20)  NULL DEFAULT 'Random' AFTER `round_count`;


-- ============================================================
-- STEP 4. brackets  ← 핵심: event_id/depth 제거, group_id FK 도입
-- ============================================================

-- 4-1. group_id 컬럼 추가 (nullable 우선)
ALTER TABLE `brackets`
    ADD COLUMN `group_id`               INT UNSIGNED    NULL AFTER `bracket_id`,
    ADD COLUMN `max_capacity`           INT             NOT NULL DEFAULT 2 AFTER `group_id`,
    ADD COLUMN `advance_count`          INT             NOT NULL DEFAULT 1 AFTER `max_capacity`,
    ADD COLUMN `next_winner_bracket_id` BIGINT UNSIGNED NULL DEFAULT NULL
        COMMENT '승자 이동 bracket_id (SE/DE용)'
        AFTER `winner_entrant_id`,
    ADD COLUMN `next_loser_bracket_id`  BIGINT UNSIGNED NULL DEFAULT NULL
        COMMENT '패자 이동 bracket_id (DE LB 진출용)'
        AFTER `next_winner_bracket_id`;

-- 4-2 전제 (조회 0건·고아 삭제 방지):
--   각 brackets 행의 (event_id, depth)마다 bracket_groups 에 동일 키 행이 있어야 4-2 UPDATE 가 group_id 를 채움.
--   STEP 2b 가 brackets 기준 누락 그룹을 선INSERT 하므로, 일반적인 “그룹 없음” 누락은 여기서 상당 부분 해소됨.
--   legacy_single_tournament_table.sql 만 적용 후 레거시 sp_bracket_single_insert 만 쓴 경우,
--   bracket_groups 가 비어 있으면 group_id 가 전부 NULL → 4-2-3 에서 brackets 가 삭제될 수 있음.
--   테이블 마이그레이션 후에는 반드시 schema/unified_tournament_se_proc.sql 로 프로시저 재배포
--   (sp_bracket_entries_groups_participants_select 가 group_id 조인 버전으로 교체되어야 함).

-- 4-2. group_id 값 채우기 (기존 event_id + depth → bracket_groups.group_id)
UPDATE `brackets` b
INNER JOIN `bracket_groups` bg
    ON b.`event_id` = bg.`event_id` AND b.`depth` = bg.`depth`
SET b.`group_id` = bg.`group_id`;

-- 4-2-1. 매핑 확인 (group_id가 NULL인 고아 행 개수 확인)
SELECT COUNT(*) AS orphaned_brackets FROM `brackets` WHERE `group_id` IS NULL;

-- 4-2-2. 고아 행 자식 데이터 먼저 삭제 (FK 순서 역방향)
--         bracket_groups에 매핑되지 않는 brackets의 자식(bracket_entries, bracket_sets) 삭제
DELETE bs FROM `bracket_sets` bs
INNER JOIN `brackets` b ON bs.`bracket_id` = b.`bracket_id`
WHERE b.`group_id` IS NULL;

DELETE be FROM `bracket_entries` be
INNER JOIN `brackets` b ON be.`bracket_id` = b.`bracket_id`
WHERE b.`group_id` IS NULL;

-- 4-2-3. 고아 brackets 행 삭제
DELETE FROM `brackets` WHERE `group_id` IS NULL;

-- 4-3. group_id NOT NULL 확정 + FK + UNIQUE
ALTER TABLE `brackets`
    MODIFY COLUMN `group_id` INT UNSIGNED NOT NULL,
    ADD CONSTRAINT `fk_brackets_group`
        FOREIGN KEY (`group_id`) REFERENCES `bracket_groups` (`group_id`)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    ADD UNIQUE KEY `uq_group_order` (`group_id`, `order`);

-- 4-4. 기존 event_id, depth 제거
-- QA 덤프 등에 UNIQUE(event_id, depth, order)가 있으면 컬럼 DROP 시 1062가 날 수 있음 → 인덱스 선삭제
SELECT COUNT(*) INTO @v_exist FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'brackets' AND INDEX_NAME = 'event_id_depth_order';
SET @v_sql := IF(@v_exist > 0, 'ALTER TABLE brackets DROP INDEX event_id_depth_order', 'SELECT 1');
PREPARE mstmt FROM @v_sql;
EXECUTE mstmt;
DEALLOCATE PREPARE mstmt;

ALTER TABLE `brackets`
    DROP COLUMN `event_id`,
    DROP COLUMN `depth`;


-- ============================================================
-- STEP 5. bracket_entries
-- 수정: score TINYINT → INT
-- 추가: slot_index, seed_no, rank_in_match, is_advanced, FK
-- ============================================================
ALTER TABLE `bracket_entries`
    MODIFY COLUMN `score`       INT          NOT NULL DEFAULT 0
        COMMENT '누적 점수 (FFA total_score 포함)',
    ADD COLUMN `slot_index`    TINYINT      NULL DEFAULT NULL
        COMMENT 'SE/DE 슬롯: 0=위/A, 1=아래/B. FFA=NULL'
        AFTER `participant_id`,
    ADD COLUMN `seed_no`       INT          NULL DEFAULT NULL
        COMMENT 'FFA 드래그앤드롭 슬롯'
        AFTER `slot_index`,
    ADD COLUMN `rank_in_match` INT          NULL DEFAULT NULL
        COMMENT '매치/조 내 순위. SE/DE=NULL, FFA=1..N'
        AFTER `score`,
    ADD COLUMN `is_advanced`   TINYINT(1)   NOT NULL DEFAULT 0
        COMMENT '1:다음 라운드 진출 확정'
        AFTER `rank_in_match`;

-- FK는 엄격하게 분리 (기존 SE DB에는 보통 없음 → 최초 1회 ADD. 재실행 시 1826 중복이면 스킵)
ALTER TABLE `bracket_entries`
    ADD CONSTRAINT `fk_entries_bracket`
        FOREIGN KEY (`bracket_id`) REFERENCES `brackets` (`bracket_id`)
        ON DELETE RESTRICT ON UPDATE CASCADE;


-- ============================================================
-- STEP 6. bracket_sets
-- 수정: bracket_id/participant_id UNSIGNED 통일
-- 추가: score (FFA 세트별 점수)
-- ============================================================
ALTER TABLE `bracket_sets`
    MODIFY COLUMN `bracket_id`     BIGINT UNSIGNED NOT NULL,
    MODIFY COLUMN `participant_id` INT UNSIGNED    NOT NULL,
    ADD COLUMN `score` INT NOT NULL DEFAULT 0
        COMMENT '세트 점수. SE/DE=0(미사용), FFA=실점수'
        AFTER `set_order`;

-- 저장 프로시저는 DDL과 분리 배포:
--   DE → schema/unified_tournament_de_proc.sql
--   SE → schema/unified_tournament_se_proc.sql

SET FOREIGN_KEY_CHECKS = 1;

-- 완료 확인
SELECT 'Migration complete' AS STATUS;
SHOW COLUMNS FROM `bracket_groups`;
SHOW COLUMNS FROM `brackets`;

-- ============================================================
-- 검증 쿼리 (마이그레이션 완료 후 실행 권장)
-- 목적: group_id 매핑·FK·고유 제약·자식 테이블 정합성 점검
-- 기대: 아래 각 SELECT의 “문제 건수” 를 0에 가깝게 유지 (이벤트별 설명은 주석 참고)
-- 통합 전 baseline: unified_tournament_table_migration_verify.sql PART A
-- 통합 후 비교용 이벤트별 brackets 합: 동 파일 V10
-- ============================================================

-- V1. brackets → bracket_groups FK 역추적 실패 (고아 group_id)
SELECT
    'V1_orphan_bracket_group_id' AS chk_id,
    COUNT(*) AS cnt_bad
FROM `brackets` b
LEFT JOIN `bracket_groups` bg ON bg.group_id = b.group_id
WHERE bg.group_id IS NULL;

-- V2. (group_id, order) 중복 — uq_group_order 위반
SELECT
    'V2_dup_group_order' AS chk_id,
    COUNT(*) AS cnt_bad
FROM (
    SELECT b.group_id, b.`order`, COUNT(*) AS c
    FROM `brackets` b
    GROUP BY b.group_id, b.`order`
    HAVING c > 1
) t;

-- V3. bracket_groups (event_id, depth) 중복 — uq_event_depth 위반
SELECT
    'V3_dup_event_depth' AS chk_id,
    COUNT(*) AS cnt_bad
FROM (
    SELECT bg.event_id, bg.depth, COUNT(*) AS c
    FROM `bracket_groups` bg
    GROUP BY bg.event_id, bg.depth
    HAVING c > 1
) t;

-- V4. bracket_entries → brackets 고아 (존재하지 않는 bracket_id)
SELECT
    'V4_orphan_bracket_entries' AS chk_id,
    COUNT(*) AS cnt_bad
FROM `bracket_entries` be
LEFT JOIN `brackets` b ON b.bracket_id = be.bracket_id
WHERE b.bracket_id IS NULL;

-- V5. bracket_sets → brackets 고아
SELECT
    'V5_orphan_bracket_sets' AS chk_id,
    COUNT(*) AS cnt_bad
FROM `bracket_sets` bs
LEFT JOIN `brackets` b ON b.bracket_id = bs.bracket_id
WHERE b.bracket_id IS NULL;

-- V6. 이벤트별: 그룹은 있는데 매치(brackets)가 0인 이벤트 (데이터 미생성·삭제 과다 의심)
SELECT
    'V6_events_groups_without_brackets' AS chk_id,
    bg.event_id,
    COUNT(DISTINCT bg.group_id) AS cnt_groups,
    COUNT(b.bracket_id) AS cnt_brackets
FROM `bracket_groups` bg
LEFT JOIN `brackets` b ON b.group_id = bg.group_id
GROUP BY bg.event_id
HAVING cnt_groups > 0 AND cnt_brackets = 0;

-- V7. 이벤트별 bracket_type 분포 (0건 이벤트는 상위 앱/시드 확인용)
SELECT
    'V7_event_bracket_type_summary' AS chk_id,
    bg.event_id,
    bg.bracket_type,
    COUNT(DISTINCT bg.group_id) AS cnt_groups,
    COUNT(b.bracket_id) AS cnt_brackets
FROM `bracket_groups` bg
LEFT JOIN `brackets` b ON b.group_id = bg.group_id
GROUP BY bg.event_id, bg.bracket_type
ORDER BY bg.event_id, bg.bracket_type;

-- V8. participants: checkin_dt 있는데 checkin_status=0 인 행 (STEP 1-3 정합성)
SELECT
    'V8_participants_checkin_mismatch' AS chk_id,
    COUNT(*) AS cnt_bad
FROM `participants` p
WHERE p.checkin_dt IS NOT NULL AND IFNULL(p.checkin_status, 0) = 0;

-- V9. 통합 컬럼 존재 여부 (스키마 버전 확인)
SELECT
    'V9_schema_columns' AS chk_id,
    SUM(c.TABLE_NAME = 'brackets' AND c.COLUMN_NAME = 'group_id') AS brackets_has_group_id,
    SUM(c.TABLE_NAME = 'brackets' AND c.COLUMN_NAME = 'event_id') AS brackets_still_has_event_id,
    SUM(c.TABLE_NAME = 'bracket_groups' AND c.COLUMN_NAME = 'group_id') AS bg_has_group_id,
    SUM(c.TABLE_NAME = 'bracket_groups' AND c.COLUMN_NAME = 'bracket_type') AS bg_has_bracket_type
FROM information_schema.COLUMNS c
WHERE c.TABLE_SCHEMA = DATABASE()
  AND c.TABLE_NAME IN ('brackets', 'bracket_groups');
