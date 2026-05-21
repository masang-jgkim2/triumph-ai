-- --------------------------------------------------------
-- 호스트:                          172.31.40.228
-- 서버 버전:                        8.0.45 - MySQL Community Server - GPL
-- 서버 OS:                        Linux
-- HeidiSQL 버전:                  12.8.0.6908
-- --------------------------------------------------------

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8 */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

-- 테이블 triumph.brackets 구조 내보내기
CREATE TABLE IF NOT EXISTS `brackets` (
  `bracket_id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `group_id` int unsigned NOT NULL,
  `max_capacity` int NOT NULL DEFAULT '2',
  `advance_count` int NOT NULL DEFAULT '1',
  `order` int NOT NULL,
  `match_point` tinyint NOT NULL DEFAULT '1',
  `winner_entrant_id` int NOT NULL DEFAULT '0',
  `next_winner_bracket_id` bigint unsigned DEFAULT NULL COMMENT '승자 이동 bracket_id (SE/DE용)',
  `next_loser_bracket_id` bigint unsigned DEFAULT NULL COMMENT '패자 이동 bracket_id (DE LB 진출용)',
  `status` tinyint(1) NOT NULL DEFAULT '0',
  `start_dt` datetime DEFAULT NULL,
  `match_start_dt` datetime DEFAULT NULL,
  `match_end_dt` datetime DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`bracket_id`),
  UNIQUE KEY `uq_group_order` (`group_id`,`order`),
  CONSTRAINT `fk_brackets_group` FOREIGN KEY (`group_id`) REFERENCES `bracket_groups` (`group_id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=2745024 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 내보낼 데이터가 선택되어 있지 않습니다.

-- 테이블 triumph.bracket_entries 구조 내보내기
CREATE TABLE IF NOT EXISTS `bracket_entries` (
  `bracket_id` bigint unsigned NOT NULL,
  `participant_id` int unsigned NOT NULL,
  `slot_index` tinyint DEFAULT NULL COMMENT 'SE/DE 슬롯: 0=위/A, 1=아래/B. FFA=NULL',
  `seed_no` int DEFAULT NULL COMMENT 'FFA 드래그앤드롭 슬롯',
  `score` int NOT NULL DEFAULT '0' COMMENT '누적 점수 (FFA total_score 포함)',
  `rank_in_match` int DEFAULT NULL COMMENT '매치/조 내 순위. SE/DE=NULL, FFA=1..N',
  `is_advanced` tinyint(1) NOT NULL DEFAULT '0' COMMENT '1:다음 라운드 진출 확정',
  `status` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`bracket_id`,`participant_id`),
  CONSTRAINT `fk_entries_bracket` FOREIGN KEY (`bracket_id`) REFERENCES `brackets` (`bracket_id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 내보낼 데이터가 선택되어 있지 않습니다.

-- 테이블 triumph.bracket_groups 구조 내보내기
CREATE TABLE IF NOT EXISTS `bracket_groups` (
  `group_id` int unsigned NOT NULL AUTO_INCREMENT,
  `event_id` int NOT NULL,
  `depth` int NOT NULL,
  `bracket_type` enum('SE','DE_WB','DE_LB','DE_GF','FFA') NOT NULL DEFAULT 'SE' COMMENT 'SE:싱글, DE_WB:더블승자조, DE_LB:패자조, DE_GF:결승, FFA:포인트제',
  `title` varchar(100) DEFAULT NULL,
  `round_count` int NOT NULL DEFAULT '1',
  `advancement_strategy` varchar(20) DEFAULT 'Random',
  `start_dt` datetime DEFAULT NULL,
  `auto_judge` tinyint DEFAULT '0',
  `created_dt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_dt` datetime DEFAULT NULL,
  PRIMARY KEY (`group_id`),
  UNIQUE KEY `uq_event_depth` (`event_id`,`depth`)
) ENGINE=InnoDB AUTO_INCREMENT=5366 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 내보낼 데이터가 선택되어 있지 않습니다.

-- 테이블 triumph.bracket_sets 구조 내보내기
CREATE TABLE IF NOT EXISTS `bracket_sets` (
  `bracket_id` bigint unsigned NOT NULL,
  `participant_id` int unsigned NOT NULL,
  `set_order` tinyint NOT NULL,
  `score` int NOT NULL DEFAULT '0' COMMENT '세트 점수. SE/DE=0(미사용), FFA=실점수',
  `winlose` tinyint(1) DEFAULT NULL,
  `judge_image_url` varchar(512) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `create_dt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `update_dt` datetime DEFAULT NULL,
  PRIMARY KEY (`bracket_id`,`participant_id`,`set_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 내보낼 데이터가 선택되어 있지 않습니다.

-- 프로시저 triumph.sp_brackets_delete 구조 내보내기
DELIMITER //
CREATE PROCEDURE `sp_brackets_delete`(
	IN `p_bracket_id` BIGINT



)
BEGIN
    DECLARE ret INT DEFAULT 0;

    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SELECT 'EXP' AS 'RETURN';
    END;

    DELETE FROM brackets WHERE bracket_id = p_bracket_id;

    SELECT ROW_COUNT() INTO ret;
    
    IF ret > 0 THEN
        SELECT 'SUC' AS 'RETURN';
    ELSE
        SELECT 'ERR' AS 'RETURN';
    END IF;
END//
DELIMITER ;

-- 프로시저 triumph.sp_brackets_insert 구조 내보내기
DELIMITER //
CREATE PROCEDURE `sp_brackets_insert`(
	IN `p_event_id` INT,
	IN `p_depth` INT,
	IN `p_order` INT,
	IN `p_match_point` TINYINT,
	IN `p_winner_entrant_id` INT,
	IN `p_status` TINYINT



)
BEGIN
    DECLARE ret INT DEFAULT 0;

    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SELECT 'EXP' AS 'RETURN';
    END;

    INSERT INTO brackets (event_id, depth, `order`, match_point, winner_entrant_id, `status`, created_at, updated_at)
    VALUES (p_event_id, p_depth, p_order, p_match_point, p_winner_entrant_id, p_status, NOW(), NULL);

    SELECT ROW_COUNT() INTO ret;
    
    IF ret > 0 THEN
        SELECT 'SUC' AS 'RETURN';
    ELSE
        SELECT 'ERR' AS 'RETURN';
    END IF;
END//
DELIMITER ;

-- 프로시저 triumph.sp_brackets_select 구조 내보내기
DELIMITER //
CREATE PROCEDURE `sp_brackets_select`(
	IN `p_bracket_id` BIGINT
)
BEGIN
    SELECT bracket_id, event_id, depth, `order`, match_point, winner_entrant_id, `status`, start_dt, created_at, updated_at
    FROM brackets
    WHERE bracket_id = p_bracket_id;
END//
DELIMITER ;

-- 프로시저 triumph.sp_brackets_update 구조 내보내기
DELIMITER //
CREATE PROCEDURE `sp_brackets_update`(
	IN `p_bracket_id` BIGINT,
	IN `p_event_id` INT,
	IN `p_depth` INT,
	IN `p_order` INT,
	IN `p_match_point` TINYINT,
	IN `p_winner_entrant_id` INT,
	IN `p_status` TINYINT,
	IN `p_start_dt` DATETIME,
	IN `p_match_start_dt` DATETIME,
	IN `p_match_end_dt` DATETIME
)
BEGIN
    DECLARE ret INT DEFAULT 0;

    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SELECT 'EXP' AS 'RETURN';
    END;

    UPDATE brackets
    SET `depth` = p_depth, `order` = p_order, match_point = p_match_point
    , `winner_entrant_id` = p_winner_entrant_id, `status` = p_status
	 , `start_dt` = p_start_dt, `match_start_dt` = p_match_start_dt, `match_end_dt` = p_match_end_dt
	 , `updated_at` = NOW()
    WHERE bracket_id = p_bracket_id and event_id = p_event_id;

    SELECT ROW_COUNT() INTO ret;
    
    IF ret > 0 THEN
        SELECT 'SUC' AS 'RETURN';
    ELSE
        SELECT 'ERR' AS 'RETURN';
    END IF;
END//
DELIMITER ;

-- 프로시저 triumph.sp_brackets_update_group 구조 내보내기
DELIMITER //
CREATE PROCEDURE `sp_brackets_update_group`(
	IN `p_event_id` INT(11),
	IN `p_depth` INT(11),
	IN `p_start_dt` DATETIME,
	IN `p_auto_judge` TINYINT
)
BEGIN
    DECLARE ret INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SELECT 'ERR' AS `RETURN`;
    END;

    
    IF p_event_id IS NULL OR p_depth IS NULL OR p_auto_judge IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid parameter';
    END IF;

    UPDATE brackets
    SET    start_dt   = p_start_dt,
           auto_judge = p_auto_judge,
           updated_at = NOW()
    WHERE  event_id = p_event_id
      AND  depth    = p_depth;

    SET ret = ROW_COUNT();

    IF ret > 0 THEN
        SELECT 'SUC' AS `RETURN`;
    ELSE
        SELECT 'ERR' AS `RETURN`;
    END IF;
END//
DELIMITER ;

-- 프로시저 triumph.sp_bracket_adjudge_auto 구조 내보내기
DELIMITER //
CREATE PROCEDURE `sp_bracket_adjudge_auto`(IN p_event_id INT)
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_bracket_id BIGINT;
    DECLARE v_event_id INT;
    DECLARE v_group_depth INT;
    DECLARE v_order INT;
    DECLARE v_nwid BIGINT;
    DECLARE v_nlid BIGINT;

    -- MySQL: 변수 → CURSOR → HANDLER 순서 필수 (EXIT HANDLER를 CURSOR 앞에 두면 1338)
    DECLARE cur1 CURSOR FOR
        SELECT b.bracket_id, bg.event_id, bg.depth, b.`order`, b.next_winner_bracket_id, b.next_loser_bracket_id
        FROM `brackets` b
        INNER JOIN `bracket_groups` bg ON b.group_id = bg.group_id
        INNER JOIN `events` e ON bg.event_id = e.event_id
        WHERE e.`status` = 2
          AND bg.bracket_type = 'SE'
          AND (p_event_id IS NULL OR p_event_id = 0 OR bg.event_id = p_event_id)
          AND bg.auto_judge = 1
          AND (bg.start_dt IS NULL OR bg.start_dt <= NOW())
          AND b.`status` = 2
          AND (
              SELECT COUNT(DISTINCT be.participant_id)
              FROM `bracket_entries` be
              LEFT JOIN `bracket_sets` bs ON be.bracket_id = bs.bracket_id AND be.participant_id = bs.participant_id
              WHERE be.bracket_id = b.bracket_id AND be.status = 2 AND bs.bracket_id IS NOT NULL
          ) = 2
          AND EXISTS (
              SELECT 1
              FROM `bracket_sets` bs_chk
              INNER JOIN `bracket_entries` be_chk
                ON bs_chk.bracket_id = be_chk.bracket_id
               AND bs_chk.participant_id = be_chk.participant_id
              WHERE bs_chk.bracket_id = b.bracket_id
                AND be_chk.status = 2
              GROUP BY bs_chk.participant_id
              HAVING SUM(bs_chk.winlose) = b.match_point
          )
          AND NOT EXISTS (
              SELECT 1
              FROM `bracket_sets` bs_x
              INNER JOIN `bracket_entries` be_x ON bs_x.bracket_id = be_x.bracket_id
                  AND bs_x.participant_id = be_x.participant_id
              WHERE bs_x.bracket_id = b.bracket_id AND be_x.status = 2
              GROUP BY bs_x.set_order
              HAVING SUM(bs_x.winlose) <> 1
          )
        LIMIT 128;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'EXP' AS 'RETURN', 'sp_bracket_adjudge_auto failed' AS MSG;
    END;

    OPEN cur1;
    read_loop: LOOP
        FETCH cur1 INTO v_bracket_id, v_event_id, v_group_depth, v_order, v_nwid, v_nlid;
        IF done THEN LEAVE read_loop; END IF;

        BEGIN
            DECLARE v_p1_id INT; DECLARE v_p2_id INT;
            DECLARE v_p1_score INT; DECLARE v_p2_score INT;
            DECLARE v_p1_dummy TINYINT; DECLARE v_p2_dummy TINYINT;
            DECLARE v_winner_id INT; DECLARE v_loser_id INT;
            DECLARE v_win_status TINYINT;
            DECLARE v_lose_status TINYINT DEFAULT 5;
            DECLARE v_win_slot TINYINT;
            DECLARE v_los_slot TINYINT;

            SELECT
                be1.participant_id,
                (SELECT IFNULL(SUM(bs.winlose), 0) FROM `bracket_sets` bs WHERE bs.bracket_id = be1.bracket_id AND bs.participant_id = be1.participant_id),
                p1.dummy,
                be2.participant_id,
                (SELECT IFNULL(SUM(bs.winlose), 0) FROM `bracket_sets` bs WHERE bs.bracket_id = be2.bracket_id AND bs.participant_id = be2.participant_id),
                p2.dummy
            INTO v_p1_id, v_p1_score, v_p1_dummy, v_p2_id, v_p2_score, v_p2_dummy
            FROM `bracket_entries` be1
            JOIN `participants` p1 ON be1.participant_id = p1.participant_id
            JOIN `bracket_entries` be2 ON be1.bracket_id = be2.bracket_id AND be1.participant_id < be2.participant_id
            JOIN `participants` p2 ON be2.participant_id = p2.participant_id
            WHERE be1.bracket_id = v_bracket_id AND be1.status = 2 AND be2.status = 2
            LIMIT 1;

            IF v_p1_score > v_p2_score THEN
                SET v_winner_id = v_p1_id; SET v_loser_id = v_p2_id; SET v_win_status = 4;
            ELSEIF v_p2_score > v_p1_score THEN
                SET v_winner_id = v_p2_id; SET v_loser_id = v_p1_id; SET v_win_status = 4;
            ELSE
                IF v_p1_dummy = 0 AND v_p2_dummy = 1 THEN
                    SET v_winner_id = v_p1_id; SET v_loser_id = v_p2_id; SET v_win_status = 7;
                ELSEIF v_p1_dummy = 1 AND v_p2_dummy = 0 THEN
                    SET v_winner_id = v_p2_id; SET v_loser_id = v_p1_id; SET v_win_status = 7;
                ELSEIF v_p1_dummy = 1 AND v_p2_dummy = 1 THEN
                    IF RAND() < 0.5 THEN SET v_winner_id = v_p1_id; SET v_loser_id = v_p2_id;
                    ELSE SET v_winner_id = v_p2_id; SET v_loser_id = v_p1_id; END IF;
                    SET v_win_status = 7;
                ELSE
                    SET v_winner_id = NULL;
                    SELECT CONCAT(
                        'JUDGMENT DELAY: 유저 간 동점',
                        v_event_id, '-', v_bracket_id, '-', v_group_depth, '-', v_order
                    ) AS 'RETURN';
                END IF;
            END IF;

            IF v_winner_id IS NOT NULL THEN
                SELECT IFNULL(slot_index, 0) INTO v_win_slot FROM `bracket_entries` WHERE bracket_id = v_bracket_id AND participant_id = v_winner_id LIMIT 1;
                SET v_los_slot = 1 - v_win_slot;

                START TRANSACTION;

                UPDATE `brackets`
                SET winner_entrant_id = v_winner_id,
                    `status` = 3,
                    match_end_dt = NOW(),
                    update_dt = NOW()
                WHERE bracket_id = v_bracket_id;

                UPDATE `bracket_entries`
                SET `status` = v_win_status,
                    score = (CASE WHEN participant_id = v_winner_id THEN (CASE WHEN v_winner_id = v_p1_id THEN v_p1_score ELSE v_p2_score END) ELSE score END),
                    is_advanced = IF(v_nwid IS NOT NULL, 1, is_advanced),
                    update_dt = NOW()
                WHERE bracket_id = v_bracket_id AND participant_id = v_winner_id;

                UPDATE `bracket_entries`
                SET `status` = v_lose_status,
                    score = (CASE WHEN participant_id = v_loser_id THEN (CASE WHEN v_loser_id = v_p1_id THEN v_p1_score ELSE v_p2_score END) ELSE score END),
                    is_advanced = IF(v_nlid IS NOT NULL, 1, 0),
                    update_dt = NOW()
                WHERE bracket_id = v_bracket_id AND participant_id = v_loser_id;

                IF v_nwid IS NOT NULL THEN
                    INSERT INTO `bracket_entries` (bracket_id, participant_id, slot_index, `status`)
                    VALUES (v_nwid, v_winner_id, v_win_slot, 0)
                    ON DUPLICATE KEY UPDATE update_dt = NOW();
                END IF;

                IF v_nlid IS NOT NULL THEN
                    INSERT INTO `bracket_entries` (bracket_id, participant_id, slot_index, `status`)
                    VALUES (v_nlid, v_loser_id, v_los_slot, 0)
                    ON DUPLICATE KEY UPDATE update_dt = NOW();
                END IF;

                BEGIN
                    DECLARE v_total INT DEFAULT 0;
                    DECLARE v_finished INT DEFAULT 0;

                    SELECT COUNT(*) INTO v_total
                    FROM `brackets` b2
                    INNER JOIN `bracket_groups` bg3 ON b2.group_id = bg3.group_id
                    WHERE bg3.event_id = v_event_id AND bg3.bracket_type = 'SE';

                    SELECT COUNT(*) INTO v_finished
                    FROM `brackets` b2
                    INNER JOIN `bracket_groups` bg3 ON b2.group_id = bg3.group_id
                    WHERE bg3.event_id = v_event_id AND bg3.bracket_type = 'SE' AND b2.`status` >= 3;

                    IF v_total > 0 AND v_total = v_finished THEN
                        UPDATE `events`
                        SET `status` = 3,
                            updated_dt = NOW()
                        WHERE event_id = v_event_id;
                    END IF;
                END;

                COMMIT;
            END IF;
        END;
    END LOOP;
    CLOSE cur1;
END//
DELIMITER ;

-- 프로시저 triumph.sp_bracket_adjudge_reset 구조 내보내기
DELIMITER //
CREATE PROCEDURE `sp_bracket_adjudge_reset`(
    IN p_event_id INT,
    IN p_depth INT,
    IN p_order INT,
    IN p_set_init INT
)
BEGIN
    DECLARE v_bracket_id BIGINT DEFAULT NULL;
    DECLARE v_winner_id INT DEFAULT 0;
    DECLARE v_current_status TINYINT DEFAULT 0;
    DECLARE v_nwid BIGINT DEFAULT NULL;
    DECLARE v_nwst TINYINT DEFAULT 0;
    DECLARE v_nlid BIGINT DEFAULT NULL;
    DECLARE v_nlst TINYINT DEFAULT 0;
    DECLARE v_closed_room INT DEFAULT 0;
    DECLARE v_can TINYINT DEFAULT 1;
    DECLARE v_msg VARCHAR(128) DEFAULT 'SUC';
    DECLARE v_u INT;
    DECLARE v_loser_id INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'EXP' AS 'RETURN', 'sp_bracket_adjudge_reset failed' AS MSG;
    END;

    -- p_depth: 레거시와 동일 — bracket_groups.depth 값 (8, 4, 2 등), 참가 규모(LOG2)가 아님
    SET v_u = p_depth;

    SELECT b.bracket_id, b.winner_entrant_id, b.`status`, b.next_winner_bracket_id, b.next_loser_bracket_id
    INTO v_bracket_id, v_winner_id, v_current_status, v_nwid, v_nlid
    FROM `brackets` b
    INNER JOIN `bracket_groups` bg ON b.group_id = bg.group_id
    WHERE bg.event_id = p_event_id AND bg.bracket_type = 'SE' AND bg.depth = v_u AND b.`order` = p_order
    LIMIT 1;

    IF v_can = 1 AND v_bracket_id IS NULL THEN
        SET v_can = 0;
        SET v_msg = 'ERROR: 해당 대진 정보가 없습니다.';
    END IF;

    IF v_can = 1 AND (v_current_status <> 3 OR v_winner_id = 0) THEN
        SET v_can = 0;
        SET v_msg = 'ERROR: 판정 완료된 경기가 아닙니다.';
    END IF;

    IF v_can = 1 AND v_nwid IS NOT NULL THEN
        SELECT `status` INTO v_nwst FROM `brackets` WHERE bracket_id = v_nwid LIMIT 1;
        IF v_nwst > 0 THEN
            SET v_can = 0;
            SET v_msg = 'ERROR: 다음 라운드 경기가 이미 진행 중입니다.';
        END IF;
    END IF;

    IF v_can = 1 AND v_nlid IS NOT NULL THEN
        SELECT `status` INTO v_nlst FROM `brackets` WHERE bracket_id = v_nlid LIMIT 1;
        IF v_nlst > 0 THEN
            SET v_can = 0;
            SET v_msg = 'ERROR: 관련 경기(3/4위전 등)가 이미 진행 중입니다.';
        END IF;
    END IF;

    IF v_can = 1 THEN
        START TRANSACTION;

        SELECT participant_id INTO v_loser_id
        FROM `bracket_entries`
        WHERE bracket_id = v_bracket_id AND participant_id <> v_winner_id
        LIMIT 1;

        SELECT COUNT(*) INTO v_closed_room
        FROM `chat_rooms` cr
        WHERE cr.event_id = p_event_id
          AND cr.closed_dt IS NOT NULL;

        IF v_nwid IS NOT NULL THEN
            DELETE FROM `bracket_entries` WHERE bracket_id = v_nwid AND participant_id = v_winner_id;
        END IF;

        IF v_nlid IS NOT NULL AND v_loser_id <> 0 THEN
            DELETE FROM `bracket_entries` WHERE bracket_id = v_nlid AND participant_id = v_loser_id;
        END IF;

        UPDATE `brackets`
        SET winner_entrant_id = 0,
            `status` = 0,
            match_end_dt = NULL,
            update_dt = NOW()
        WHERE bracket_id = v_bracket_id;

        UPDATE `bracket_entries`
        SET score = 0, `status` = 0, update_dt = NOW()
        WHERE bracket_id = v_bracket_id;

        IF v_closed_room > 0 THEN
            UPDATE `chat_rooms` cr
            SET cr.closed_dt = NULL,
                cr.updated_dt = NOW()
            WHERE cr.event_id = p_event_id;
        END IF;

        IF IFNULL(p_set_init, 0) = 1 THEN
            DELETE FROM `bracket_sets` WHERE bracket_id = v_bracket_id;
        END IF;

        -- 결승 스테이지(depth=2) 초기화 시 대회 상태 복귀
        IF p_depth = 2 THEN
            UPDATE `events` e SET e.`status` = 2 WHERE e.event_id = p_event_id;
        END IF;

        COMMIT;
    END IF;

    SELECT v_msg AS 'RETURN';
END//
DELIMITER ;

-- 프로시저 triumph.sp_bracket_entries_delete 구조 내보내기
DELIMITER //
CREATE PROCEDURE `sp_bracket_entries_delete`(
	IN `p_participant_id` INT,
	IN `p_bracket_id` BIGINT
)
BEGIN
    DECLARE ret INT DEFAULT 0;

    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SELECT 'EXP' AS 'RETURN';
    END;

    DELETE FROM bracket_entries
    WHERE participant_id = p_participant_id
    AND bracket_id = p_bracket_id;

    SELECT ROW_COUNT() INTO ret; 
	
    IF ret > 0 THEN
        SELECT 'SUC' AS 'RETURN';
    ELSE
        SELECT 'ERR' AS 'RETURN';
    END IF;
END//
DELIMITER ;

-- 프로시저 triumph.sp_bracket_entries_groups_participants_select 구조 내보내기
DELIMITER //
CREATE PROCEDURE `sp_bracket_entries_groups_participants_select`(
    IN `p_event_id` INT
)
    COMMENT '이벤트별 브라켓·엔트리·참가자 조회 (레거시 결과셋 형태 호환 + 통합 스키마)'
BEGIN
    /*
    -- 기존 로직 원문 보관 (마이그레이션 전 DB 참고·통합 후 실행 불가)

    SELECT
        br.bracket_id,
        br.event_id,
        br.depth,
        br.`order`,
        br.match_point,
        br.start_dt,
        br.winner_entrant_id,
        br.status,
        en.score,
        en.participant_id,
        pa.entrant_name,
        pa.participant_type,
        pa.dummy,
        en.status AS entry_status,
        pa.entrant_image_url AS image_url,
        (SELECT bg.auto_judge 
         FROM bracket_groups AS bg
         WHERE bg.event_id = br.event_id
           AND bg.depth   = br.depth
         LIMIT 1) AS auto_judge,
        (SELECT bg.start_dt 
         FROM bracket_groups AS bg
         WHERE bg.event_id = br.event_id
           AND bg.depth   = br.depth
         LIMIT 1) AS group_start_dt
    FROM brackets AS br
    LEFT JOIN bracket_entries AS en
        ON en.bracket_id = br.bracket_id
    LEFT JOIN participants AS pa
        ON en.participant_id = pa.participant_id
    WHERE br.event_id = p_event_id
    ORDER BY br.depth DESC, br.`order` ASC;
    */

    -- ── 통합 스키마 개선(실행) ────────────────────────────────────
    -- 조인: brackets.group_id = bracket_groups.group_id, 이벤트는 bg.event_id
    -- 레거시와 동일한 결과 컬럼 세트 유지
    -- SE만 노출: 해당 이벤트에 SE 매치(bracket)가 있을 때. 없으면 전 타입 노출.
    SELECT
        br.bracket_id,
        bg.event_id,
        bg.depth,
        br.`order`,
        br.match_point,
        br.start_dt,
        br.winner_entrant_id,
        br.status,
        en.score,
        en.participant_id,
        pa.entrant_name,
        pa.participant_type,
        pa.dummy,
        en.status AS entry_status,
        pa.entrant_image_url AS image_url,
        bg.auto_judge,
        bg.start_dt AS group_start_dt
    FROM `brackets` AS br
    INNER JOIN `bracket_groups` AS bg
        ON br.group_id = bg.group_id
    LEFT JOIN `bracket_entries` AS en ON en.bracket_id = br.bracket_id
    LEFT JOIN `participants` AS pa ON en.participant_id = pa.participant_id
    WHERE bg.event_id = p_event_id
      AND (
          bg.bracket_type = 'SE'
          OR NOT EXISTS (
              SELECT 1
              FROM `bracket_groups` AS bg_se
              INNER JOIN `brackets` AS b_se ON b_se.group_id = bg_se.group_id
              WHERE bg_se.event_id = p_event_id
                AND bg_se.bracket_type = 'SE'
          )
      )
    ORDER BY bg.depth DESC, br.`order` ASC, IFNULL(en.slot_index, 0), IFNULL(en.participant_id, 0);

    /*
    -- ── 통합 개선 테스트(참고): LEFT JOIN 느슨 조회 ───────────────
    -- 목적: bracket_groups 매핑 누락/비정상 데이터가 있어도 bracket 자체는 조회.
    -- 주의: 통합 스키마 FK가 정상이면 INNER/LEFT 결과는 동일해야 함.
    SELECT
        br.bracket_id,
        bg.event_id,
        bg.depth,
        br.`order`,
        br.match_point,
        br.start_dt,
        br.winner_entrant_id,
        br.status,
        en.score,
        en.participant_id,
        pa.entrant_name,
        pa.participant_type,
        pa.dummy,
        en.status AS entry_status,
        pa.entrant_image_url AS image_url,
        bg.auto_judge,
        bg.start_dt AS group_start_dt
    FROM `brackets` AS br
    LEFT JOIN `bracket_groups` AS bg
        ON br.group_id = bg.group_id
    LEFT JOIN `bracket_entries` AS en ON en.bracket_id = br.bracket_id
    LEFT JOIN `participants` AS pa ON en.participant_id = pa.participant_id
    WHERE (bg.event_id = p_event_id OR bg.event_id IS NULL)
      AND (
          bg.bracket_type = 'SE'
          OR bg.bracket_type IS NULL
          OR NOT EXISTS (
              SELECT 1
              FROM `bracket_groups` bg_se
              WHERE bg_se.event_id = p_event_id
                AND bg_se.bracket_type = 'SE'
          )
      )
    ORDER BY COALESCE(bg.depth, -1) DESC, br.`order` ASC;

    -- ── 통합 개선 SE 필터 없이 전 타입 비교 시(복사용) ───────────
    --
    -- SELECT 동일 컬럼 … FROM brackets br
    -- INNER JOIN bracket_groups bg ON bg.group_id = br.group_id AND bg.event_id = p_event_id
    -- LEFT JOIN bracket_entries ...
    -- (WHERE 의 bracket_type / NOT EXISTS 조건 줄만 제거)
    */
END//
DELIMITER ;

-- 프로시저 triumph.sp_bracket_entries_insert 구조 내보내기
DELIMITER //
CREATE PROCEDURE `sp_bracket_entries_insert`(
	IN `p_participant_id` INT,
	IN `p_bracket_id` BIGINT,
	IN `p_score` TINYINT,
	IN `p_status` TINYINT
)
BEGIN
    DECLARE ret INT DEFAULT 0;

    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SELECT 'EXP' AS 'RETURN';
    END;

    INSERT INTO bracket_entries (participant_id, bracket_id, score, `status`, created_at, updated_at)
    VALUES (p_participant_id, p_bracket_id, p_score, 0, NOW(), NULL);

    SELECT ROW_COUNT() INTO ret; 
	
    IF ret > 0 THEN
        SELECT 'SUC' AS 'RETURN';
    ELSE
        SELECT 'ERR' AS 'RETURN';
    END IF;
END//
DELIMITER ;

-- 프로시저 triumph.sp_bracket_entries_participants_members_select 구조 내보내기
DELIMITER //
CREATE PROCEDURE `sp_bracket_entries_participants_members_select`(
    IN `p_event_id` INT,
    IN `p_bracket_id` INT
)
BEGIN
    SELECT
        bg.depth,
        b.`order`,
        b.match_point,
        e.team_size,
        e.member_id AS operators_member_id,
        m.`name` AS operators_member_name,
        m.image_url AS operators_member_image_url,
        be.participant_id,
        p.participant_type,
        p.entrant_id,
        p.entrant_name,
        p.entrant_image_url,
        p.dummy AS is_dummy_team,
        me.member_id AS leader_member_id,
        me.image_url AS leader_member_image_url,
        me.`name` AS leader_member_name,
        pm.member_id AS part_member_id,
        pm.member_name AS part_member_name,
        pm.member_image_url AS part_member_image_url,
        pm.dummy AS is_dummy_member
    FROM `brackets` AS b
    INNER JOIN `bracket_groups` AS bg ON b.group_id = bg.group_id
    LEFT JOIN `events` AS e ON bg.event_id = e.event_id
    LEFT JOIN `members` AS m ON e.member_id = m.member_id
    LEFT JOIN `bracket_entries` AS be ON b.bracket_id = be.bracket_id
    LEFT JOIN `participants` AS p ON be.participant_id = p.participant_id
    LEFT JOIN `members` AS me ON p.create_member_id = me.member_id
    LEFT JOIN `participant_members` AS pm ON be.participant_id = pm.participant_id
    WHERE b.bracket_id = p_bracket_id
      AND bg.event_id = p_event_id
    ORDER BY p.participant_id DESC;
END//
DELIMITER ;

-- 프로시저 triumph.sp_bracket_entries_participants_select 구조 내보내기
DELIMITER //
CREATE PROCEDURE `sp_bracket_entries_participants_select`(
	IN `p_bracket_id` INT,
	IN `p_participant_id` INT
)
BEGIN

SELECT
    `pa`.`create_member_id`,
    `p_m`.`member_id`
FROM `bracket_entries` AS `b_e`
LEFT JOIN `participants` AS `pa`
    ON `b_e`.`participant_id` = `pa`.`participant_id`
LEFT JOIN `participant_members` AS `p_m`
    ON `b_e`.`participant_id` = `p_m`.`participant_id`
WHERE `b_e`.`participant_id` = p_participant_id
AND `b_e`.`bracket_id` = p_bracket_id;




END//
DELIMITER ;

-- 프로시저 triumph.sp_bracket_entries_select 구조 내보내기
DELIMITER //
CREATE PROCEDURE `sp_bracket_entries_select`(
	IN `p_bracket_id` INT,
	IN `p_participant_id` INT
)
BEGIN

SELECT
    `b_e`.`participant_id`,
    `b_e`.`bracket_id`,
    `b_e`.`score`,
    `b_e`.`status`,
    `b_e`.`created_at`,
    `b_e`.`updated_at`,
    `pa`.`create_member_id`
FROM `bracket_entries` AS `b_e`
LEFT JOIN `participants` AS `pa`
    ON `b_e`.`participant_id` = `pa`.`participant_id`
WHERE `b_e`.`participant_id` = p_participant_id
AND `b_e`.`bracket_id` = p_bracket_id;



END//
DELIMITER ;

-- 프로시저 triumph.sp_bracket_entries_single_delete 구조 내보내기
DELIMITER //
CREATE PROCEDURE `sp_bracket_entries_single_delete`(
	IN `p_event_id` INT,
	IN `p_depth` INT
)
BEGIN
    DECLARE ret INT DEFAULT 0;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SELECT 'EXP' AS 'RETURN';
    END;
	 
	 
	 DELETE be
	 FROM brackets b inner join bracket_entries be
	 on b.bracket_id = be.bracket_id
	 WHERE event_id = p_event_id AND depth = p_depth;
	
    SELECT ROW_COUNT() INTO ret; 
    
	 IF ret > 0 THEN
        SELECT 'SUC' AS 'RETURN';
    ELSE
        SELECT 'ERR' AS 'RETURN';
    END IF;
END//
DELIMITER ;

-- 프로시저 triumph.sp_bracket_entries_single_insert 구조 내보내기
DELIMITER //
CREATE PROCEDURE `sp_bracket_entries_single_insert`(
    IN p_event_id INT,
    IN p_depth INT,
    IN p_entries VARCHAR(2048)
)
BEGIN
    DECLARE v_ret INT DEFAULT 0;
    DECLARE v_i INT DEFAULT 1;
    DECLARE v_R INT;
    DECLARE v_u INT;
    DECLARE v_start INT DEFAULT 1;
    DECLARE v_end INT;
    DECLARE v_v1 INT;
    DECLARE v_v2 INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'EXP' AS 'RETURN';
    END;

    IF p_entries IS NULL OR TRIM(p_entries) = '' THEN
        SELECT 'ERR' AS 'RETURN', 'p_entries가 비었습니다.' AS MSG;
    ELSE
        SELECT IFNULL(MAX(bg.depth), 0) INTO v_R
        FROM `bracket_groups` bg
        WHERE bg.event_id = p_event_id AND bg.bracket_type = 'SE';

        IF v_R < 1 THEN
            SELECT 'ERR' AS 'RETURN', 'SE bracket_groups가 없습니다. sp_bracket_single_insert를 먼저 실행하세요.' AS MSG;
        ELSE
            -- p_depth: 대회 규모(4,8,16…) — 1라운드 그룹 depth 는 레거시와 동일하게 p_depth 와 같음(8강→8, 4강→4)
            SET v_u = p_depth;
            IF NOT EXISTS (
                SELECT 1 FROM `bracket_groups` bgx
                WHERE bgx.event_id = p_event_id AND bgx.bracket_type = 'SE' AND bgx.depth = v_u
            ) THEN
                SELECT 'ERR' AS 'RETURN', 'p_depth에 해당하는 SE 라운드(bracket_groups.depth)가 없습니다.' AS MSG;
            ELSE
                START TRANSACTION;

                DELETE be FROM `bracket_entries` be
                INNER JOIN `brackets` b ON b.bracket_id = be.bracket_id
                INNER JOIN `bracket_groups` bg ON bg.group_id = b.group_id
                WHERE bg.event_id = p_event_id AND bg.bracket_type = 'SE' AND bg.depth = v_u;

                SET v_start = 1;
                SET v_i = 1;
                WHILE v_start > 0 DO
                    SET v_end = LOCATE(',', p_entries, v_start);
                    IF v_end > 0 THEN
                        SET v_v1 = CAST(TRIM(SUBSTRING(p_entries, v_start, v_end - v_start)) AS UNSIGNED);
                    ELSE
                        SET v_v1 = CAST(TRIM(SUBSTRING(p_entries, v_start)) AS UNSIGNED);
                    END IF;
                    SET v_start = IF(v_end > 0, v_end + 1, 0);

                    IF v_start > 0 THEN
                        SET v_end = LOCATE(',', p_entries, v_start);
                        IF v_end > 0 THEN
                            SET v_v2 = CAST(TRIM(SUBSTRING(p_entries, v_start, v_end - v_start)) AS UNSIGNED);
                        ELSE
                            SET v_v2 = CAST(TRIM(SUBSTRING(p_entries, v_start)) AS UNSIGNED);
                        END IF;
                        SET v_start = IF(v_end > 0, v_end + 1, 0);

                        INSERT INTO `bracket_entries` (bracket_id, participant_id, slot_index, status)
                        SELECT b.bracket_id, v_v1, 0, 0
                        FROM `brackets` b
                        INNER JOIN `bracket_groups` bg ON bg.group_id = b.group_id
                        WHERE bg.event_id = p_event_id AND bg.bracket_type = 'SE' AND bg.depth = v_u AND b.`order` = v_i
                        LIMIT 1;
                        INSERT INTO `bracket_entries` (bracket_id, participant_id, slot_index, status)
                        SELECT b.bracket_id, v_v2, 1, 0
                        FROM `brackets` b
                        INNER JOIN `bracket_groups` bg ON bg.group_id = b.group_id
                        WHERE bg.event_id = p_event_id AND bg.bracket_type = 'SE' AND bg.depth = v_u AND b.`order` = v_i
                        LIMIT 1;

                        SET v_i = v_i + 1;
                    END IF;
                END WHILE;

                SELECT ROW_COUNT() INTO v_ret;
                SELECT COUNT(*) INTO v_ret FROM `bracket_entries` be
                INNER JOIN `brackets` b ON b.bracket_id = be.bracket_id
                INNER JOIN `bracket_groups` bg ON bg.group_id = b.group_id
                WHERE bg.event_id = p_event_id AND bg.bracket_type = 'SE' AND bg.depth = v_u;

                IF v_ret > 0 THEN
                    SELECT 'SUC' AS 'RETURN';
                    COMMIT;
                ELSE
                    SELECT 'ERR' AS 'RETURN', '배정된 참가자가 없습니다.' AS MSG;
                    ROLLBACK;
                END IF;
            END IF;
        END IF;
    END IF;
END//
DELIMITER ;

-- 프로시저 triumph.sp_bracket_entries_update 구조 내보내기
DELIMITER //
CREATE PROCEDURE `sp_bracket_entries_update`(
	IN `p_participant_id` INT,
	IN `p_bracket_id` BIGINT,
	IN `p_score` TINYINT,
	IN `p_status` TINYINT
)
BEGIN
    DECLARE ret INT DEFAULT 0;

    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SELECT 'EXP' AS 'RETURN';
    END;

    UPDATE bracket_entries
    SET score = p_score, `status` = p_status, updated_at = NOW()
    WHERE participant_id = p_participant_id
    AND bracket_id = p_bracket_id;

    SELECT ROW_COUNT() INTO ret; 
	
    IF ret > 0 THEN
        SELECT 'SUC' AS 'RETURN';
    ELSE
        SELECT 'ERR' AS 'RETURN';
    END IF;
END//
DELIMITER ;

-- 프로시저 triumph.sp_bracket_entry_sets_delete 구조 내보내기
DELIMITER //
CREATE PROCEDURE `sp_bracket_entry_sets_delete`(
	IN `p_bracket_id` BIGINT,
	IN `p_participant_id` INT
)
BEGIN
    DECLARE ret INT DEFAULT 0;

    DELETE bs
    FROM bracket_entries be LEFT JOIN bracket_sets bs 
    on be.bracket_id = bs.bracket_id and be.participant_id = bs.participant_id
    WHERE be.bracket_id = p_bracket_id and be.participant_id = p_participant_id;
    
    SELECT ROW_COUNT() INTO ret;
    
    IF ret > 0 THEN
        SELECT 'SUC' AS 'RETURN';
		  COMMIT;        
    ELSE
        SELECT 'ERR' AS 'RETURN';
        ROLLBACK;
    END IF;
END//
DELIMITER ;

-- 프로시저 triumph.sp_bracket_entry_sets_insert 구조 내보내기
DELIMITER //
CREATE PROCEDURE `sp_bracket_entry_sets_insert`(
	IN `p_bracket_id` BIGINT,
	IN `p_participant_id` INT,
	IN `p_winlose` VARCHAR(64),
	IN `p_judgeimageurl` VARCHAR(4086)
)
BEGIN
    DECLARE ret INT DEFAULT 0;
    
    DECLARE i INT DEFAULT 1; 

    DECLARE start_position_winlose INT DEFAULT 1;
    DECLARE end_position_winlose INT;
    DECLARE winlose INT DEFAULT 0;
    
    DECLARE start_position_judgeimageurl INT DEFAULT 1;
    DECLARE end_position_judgeimageurl INT;
    DECLARE judgeimageurl VARCHAR(256);
    
        
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'EXP' AS 'RETURN';
    END;

    
    
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp (bracket_id BIGINT, participant_id INT, set_order TINYINT, _winlose TINYINT, judge_image_url VARCHAR(512));
    TRUNCATE tmp;

    WHILE start_position_winlose > 0 DO
   

        SET end_position_winlose = LOCATE(',', p_winlose, start_position_winlose);
        SET end_position_judgeimageurl = LOCATE(',', p_judgeimageurl, start_position_judgeimageurl);

        IF end_position_winlose > 0 THEN
            SET winlose = SUBSTRING(p_winlose, start_position_winlose, end_position_winlose - start_position_winlose);
            SET judgeimageurl = SUBSTRING(p_judgeimageurl, start_position_judgeimageurl, end_position_judgeimageurl - start_position_judgeimageurl);
        ELSE
            SET winlose = SUBSTRING(p_winlose, start_position_winlose);
            SET judgeimageurl = SUBSTRING(p_judgeimageurl, start_position_judgeimageurl);
        END IF;
        
        
        IF winlose >= 1 THEN SET winlose = 1; ELSE SET winlose = 0; END IF;
        
            	

        INSERT INTO tmp(bracket_id, participant_id, set_order, _winlose, judge_image_url)
        SELECT bracket_id, participant_id, i, winlose, judgeimageurl
        FROM bracket_entries
        WHERE bracket_id = p_bracket_id and participant_id = p_participant_id;
        

        

        SET start_position_winlose = IF(end_position_winlose > 0, end_position_winlose + 1, 0);
        SET start_position_judgeimageurl = IF(end_position_judgeimageurl > 0, end_position_judgeimageurl + 1, 0);

        SET i = i + 1;
        

    END WHILE;
    

    START TRANSACTION;    
    DELETE bs
    FROM bracket_entries be LEFT JOIN bracket_sets bs 
    on be.bracket_id = bs.bracket_id and be.participant_id = bs.participant_id
    WHERE be.bracket_id = p_bracket_id and be.participant_id = p_participant_id;

    INSERT INTO bracket_sets (bracket_id, participant_id, set_order, winlose, judge_image_url, update_dt)
    SELECT bracket_id, participant_id, set_order, _winlose, judge_image_url, NOW() FROM tmp;
    
    SELECT ROW_COUNT() INTO ret;
    
    IF ret > 0 THEN
        SELECT 'SUC' AS 'RETURN';
		  COMMIT;        
    ELSE
        SELECT 'ERR' AS 'RETURN';
        ROLLBACK;
    END IF;
    
    DROP TEMPORARY TABLE IF EXISTS tmp;
END//
DELIMITER ;

-- 프로시저 triumph.sp_bracket_groups_delete 구조 내보내기
DELIMITER //
CREATE PROCEDURE `sp_bracket_groups_delete`(
	IN `p_event_id` INT,
	IN `p_depth` INT
)
proc_main: BEGIN


	DECLARE ret INT DEFAULT 0;

	
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
	BEGIN
		SELECT 'EXP' AS 'RETURN';
	END;

	
	IF (p_event_id IS NULL OR p_depth IS NULL) THEN
		SELECT 'ERR' AS 'RETURN';
		LEAVE proc_main;
	END IF;

	
	DELETE FROM bracket_groups 
	WHERE event_id = p_event_id AND depth = p_depth;

	SELECT ROW_COUNT() INTO ret;

	IF ret > 0 THEN
		SELECT 'SUC' AS 'RETURN';
	ELSE
		SELECT 'ERR' AS 'RETURN';
	END IF;
END//
DELIMITER ;

-- 프로시저 triumph.sp_bracket_groups_insert 구조 내보내기
DELIMITER //
CREATE PROCEDURE `sp_bracket_groups_insert`(
    IN p_event_id INT,
    IN p_depth INT,
    IN p_start_dt DATETIME,
    IN p_auto_judge TINYINT
)
BEGIN
    DECLARE v_ret INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'EXP' AS 'RETURN';
    END;

    IF p_event_id IS NULL OR p_event_id <= 0 OR p_depth IS NULL OR p_depth <= 0 THEN
        SELECT 'ERR' AS 'RETURN', 'event_id·depth가 유효하지 않습니다.' AS MSG;
    ELSEIF EXISTS (
        SELECT 1
        FROM `bracket_groups` bg
        WHERE bg.event_id = p_event_id
          AND bg.depth = p_depth
    ) THEN
        SELECT 'ERR' AS 'RETURN', '이미 동일 depth의 bracket_groups가 있습니다.' AS MSG;
    ELSE
        START TRANSACTION;

        INSERT INTO `bracket_groups` (
            event_id,
            depth,
            bracket_type,
            start_dt,
            auto_judge,
            created_dt,
            updated_dt
        )
        VALUES (
            p_event_id,
            p_depth,
            'SE',
            p_start_dt,
            IFNULL(p_auto_judge, 0),
            NOW(),
            NOW()
        );

        SELECT ROW_COUNT() INTO v_ret;

        IF v_ret > 0 THEN
            COMMIT;
            SELECT 'SUC' AS 'RETURN';
        ELSE
            ROLLBACK;
            SELECT 'ERR' AS 'RETURN', 'bracket_groups가 생성되지 않았습니다.' AS MSG;
        END IF;
    END IF;
END//
DELIMITER ;

-- 프로시저 triumph.sp_bracket_groups_select 구조 내보내기
DELIMITER //
CREATE PROCEDURE `sp_bracket_groups_select`(
	IN `p_event_id` INT,
	IN `p_depth` INT
)
BEGIN


	IF p_event_id > 0 THEN
		SELECT `event_id`, `depth`, `start_dt`, `auto_judge`, `created_dt`, `updated_dt`
		FROM bracket_groups
		WHERE event_id = p_event_id AND depth = p_depth;
	END IF;
END//
DELIMITER ;

-- 프로시저 triumph.sp_bracket_groups_update 구조 내보내기
DELIMITER //
CREATE PROCEDURE `sp_bracket_groups_update`(
    IN p_event_id INT,
    IN p_depth INT,
    IN p_start_dt DATETIME,
    IN p_auto_judge TINYINT
)
BEGIN
    DECLARE v_ret INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'EXP' AS 'RETURN';
    END;

    IF p_event_id IS NULL OR p_event_id <= 0 OR p_depth IS NULL OR p_depth <= 0 THEN
        SELECT 'ERR' AS 'RETURN', 'event_id·depth가 유효하지 않습니다.' AS MSG;
    ELSEIF NOT EXISTS (
        SELECT 1
        FROM `bracket_groups` bg
        WHERE bg.event_id = p_event_id
          AND bg.depth = p_depth
          AND bg.bracket_type = 'SE'
    ) THEN
        SELECT 'ERR' AS 'RETURN', 'SE bracket_groups가 없습니다.' AS MSG;
    ELSE
        START TRANSACTION;

        UPDATE `bracket_groups` bg
        SET bg.start_dt = p_start_dt,
            bg.auto_judge = IFNULL(p_auto_judge, 0),
            bg.updated_dt = NOW()
        WHERE bg.event_id = p_event_id
          AND bg.depth = p_depth
          AND bg.bracket_type = 'SE';

        SELECT ROW_COUNT() INTO v_ret;

        IF v_ret > 0 THEN
            COMMIT;
            SELECT 'SUC' AS 'RETURN';
        ELSE
            ROLLBACK;
            SELECT 'ERR' AS 'RETURN', '갱신된 행이 없습니다.' AS MSG;
        END IF;
    END IF;
END//
DELIMITER ;

-- 프로시저 triumph.sp_bracket_score_auto 구조 내보내기
DELIMITER //
CREATE PROCEDURE `sp_bracket_score_auto`(
    IN p_event_id INT,
    IN p_force TINYINT,
    IN p_player_win TINYINT
)
BEGIN
    DROP TEMPORARY TABLE IF EXISTS tmp_active_participants;
    CREATE TEMPORARY TABLE tmp_active_participants AS
    SELECT
        b.bracket_id,
        be.participant_id,
        b.match_point,
        p.dummy,
        (SELECT COUNT(*) FROM `bracket_entries` be2
         JOIN `participants` p2 ON be2.participant_id = p2.participant_id
         WHERE be2.bracket_id = b.bracket_id AND p2.dummy = 0) AS has_user_opponent,
        RAND() AS rnd_seed
    FROM `brackets` b
    INNER JOIN `bracket_groups` bg ON b.group_id = bg.group_id AND bg.bracket_type IN ('SE', 'DE_WB', 'DE_LB', 'DE_GF')
    JOIN `bracket_entries` be ON b.bracket_id = be.bracket_id
    JOIN `participants` p ON be.participant_id = p.participant_id
    WHERE (p_event_id IS NULL OR p_event_id = 0 OR bg.event_id = p_event_id)
      AND b.`status` < 3
      AND (p_force = 1 OR (p_force = 0 AND p.dummy = 1))
      AND (SELECT COUNT(*) FROM `bracket_entries` be_c WHERE be_c.bracket_id = b.bracket_id) >= 2
      AND NOT EXISTS (
          SELECT 1 FROM `bracket_sets` bs
          WHERE bs.bracket_id = be.bracket_id AND bs.participant_id = be.participant_id
      );

    DROP TEMPORARY TABLE IF EXISTS tmp_match_results;
    CREATE TEMPORARY TABLE tmp_match_results AS
    SELECT
        x.bracket_id,
        x.participant_id,
        x.match_point,
        CASE
            WHEN p_player_win = 1 AND x.dummy = 1 AND x.has_user_opponent > 0 THEN 0
            WHEN x.rn = 1 THEN x.match_point
            ELSE 0
        END AS final_score
    FROM (
        SELECT
            t.bracket_id,
            t.participant_id,
            t.match_point,
            t.dummy,
            t.has_user_opponent,
            IF(@bid = t.bracket_id, @rn := @rn + 1, @rn := 1) AS rn,
            @bid := t.bracket_id
        FROM tmp_active_participants t, (SELECT @rn := 0, @bid := 0) AS vars
        ORDER BY
            t.bracket_id ASC,
            (CASE WHEN p_player_win = 1 AND t.dummy = 0 THEN 0 ELSE 1 END) ASC,
            t.rnd_seed DESC
    ) AS x;

    INSERT INTO `bracket_sets` (bracket_id, participant_id, set_order, winlose, score)
    SELECT
        r.bracket_id,
        r.participant_id,
        seq.n AS set_order,
        IF(seq.n <= r.final_score, 1, 0) AS winlose,
        0 AS score
    FROM tmp_match_results r
    CROSS JOIN (
        SELECT 1 AS n UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5
        UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9 UNION SELECT 10
    ) AS seq
    WHERE seq.n <= r.match_point;

    UPDATE `bracket_entries` be
    INNER JOIN tmp_match_results r ON be.bracket_id = r.bracket_id AND be.participant_id = r.participant_id
    SET be.`status` = 2, be.update_dt = NOW();

    UPDATE `brackets` b
    INNER JOIN (
        SELECT be_g.bracket_id
        FROM `bracket_entries` be_g
        GROUP BY be_g.bracket_id
        HAVING MIN(IFNULL(be_g.`status`, 0)) >= 2 AND COUNT(*) >= 2
    ) AS ready ON b.bracket_id = ready.bracket_id
    SET b.`status` = 2, b.update_dt = NOW()
    WHERE b.`status` < 2
      AND NOT EXISTS (
          SELECT 1 FROM `bracket_entries` be_x
          WHERE be_x.bracket_id = b.bracket_id AND IFNULL(be_x.`status`, 0) < 2
      )
      AND b.bracket_id IN (SELECT DISTINCT bracket_id FROM tmp_match_results);

    DROP TEMPORARY TABLE IF EXISTS tmp_active_participants;
    DROP TEMPORARY TABLE IF EXISTS tmp_match_results;
END//
DELIMITER ;

-- 프로시저 triumph.sp_bracket_sets_delete 구조 내보내기
DELIMITER //
CREATE PROCEDURE `sp_bracket_sets_delete`(
	IN `p_bracket_set_id` BIGINT


)
BEGIN
    DECLARE ret INT DEFAULT 0;

    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SELECT 'EXP' AS 'RETURN';
    END;

    DELETE FROM bracket_sets
    WHERE bracket_set_id = p_bracket_set_id;
    
    SELECT ROW_COUNT() INTO ret; 
	
    IF ret > 0 THEN
        SELECT 'SUC' AS 'RETURN';
    ELSE
        SELECT 'ERR' AS 'RETURN';
    END IF;
END//
DELIMITER ;

-- 프로시저 triumph.sp_bracket_sets_insert 구조 내보내기
DELIMITER //
CREATE PROCEDURE `sp_bracket_sets_insert`(
	IN `p_bracket_id` BIGINT,
	IN `p_participant_id` INT,
	IN `p_set_order` INT,
	IN `p_winlose` TINYINT,
	IN `p_judge_image_url` VARCHAR(255)


)
BEGIN
    DECLARE ret INT DEFAULT 0;

    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SELECT 'EXP' AS 'RETURN';
    END;
    
    INSERT INTO bracket_sets (bracket_id, participant_id, set_order, winlose, judge_image_url, create_dt, update_dt)
    VALUES (p_bracket_id, p_participant_id, p_set_order, p_winlose, p_judge_image_url, NOW(), NULL);
    
    SELECT ROW_COUNT() INTO ret; 
	
    IF ret > 0 THEN
        SELECT 'SUC' AS 'RETURN';
    ELSE
        SELECT 'ERR' AS 'RETURN';
    END IF;
END//
DELIMITER ;

-- 프로시저 triumph.sp_bracket_sets_select 구조 내보내기
DELIMITER //
CREATE PROCEDURE `sp_bracket_sets_select`(
    IN p_bracket_set_id BIGINT
)
BEGIN
    SELECT bracket_set_id, bracket_id, participant_id, set_order, winlose, judge_image_url, create_dt, update_dt
    FROM bracket_sets
    WHERE bracket_set_id = p_bracket_set_id;
END//
DELIMITER ;

-- 프로시저 triumph.sp_bracket_sets_update 구조 내보내기
DELIMITER //
CREATE PROCEDURE `sp_bracket_sets_update`(
	IN `p_bracket_set_id` BIGINT,
	IN `p_score` TINYINT,
	IN `p_winlose` TINYINT,
	IN `p_judge_image_url` VARCHAR(255),
	IN `p_status` TINYINT,
	IN `p_set_end_dt` DATETIME


)
BEGIN
    DECLARE ret INT DEFAULT 0;

    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SELECT 'EXP' AS 'RETURN';
    END;
    
    UPDATE bracket_sets
    SET winlose = p_winlose, judge_image_url = p_judge_image_url, update_dt = NOW()
    WHERE bracket_set_id = p_bracket_set_id;
    
    SELECT ROW_COUNT() INTO ret; 
	
    IF ret > 0 THEN
        SELECT 'SUC' AS 'RETURN';
    ELSE
        SELECT 'ERR' AS 'RETURN';
    END IF;
END//
DELIMITER ;

-- 프로시저 triumph.sp_bracket_single_delete 구조 내보내기
DELIMITER //
CREATE PROCEDURE `sp_bracket_single_delete`(
	IN `p_event_id` INT





)
BEGIN
    DECLARE ret INT DEFAULT 0;

    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SELECT 'EXP' AS 'RETURN';
    END;
    
    DELETE FROM brackets
    WHERE event_id = p_event_id;
    
    SELECT ROW_COUNT() INTO ret; 
	
    IF ret > 0 THEN
        SELECT 'SUC' AS 'RETURN';
    ELSE
        SELECT 'ERR' AS 'RETURN';
    END IF;
END//
DELIMITER ;

-- 프로시저 triumph.sp_bracket_single_insert 구조 내보내기
DELIMITER //
CREATE PROCEDURE `sp_bracket_single_insert`(
    IN p_event_id INT,
    IN p_depth INT,
    IN p_34 TINYINT,
    IN p_points VARCHAR(128)
)
BEGIN
    DECLARE v_k INT;
    DECLARE v_i INT DEFAULT 1;
    DECLARE v_j INT DEFAULT 1;
    DECLARE v_rounds INT;
    DECLARE v_u_depth INT;
    DECLARE v_gid INT;
    DECLARE v_pt INT DEFAULT 1;
    DECLARE v_sp INT DEFAULT 1;
    DECLARE v_ep INT;
    DECLARE v_ret INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'EXP' AS 'RETURN';
    END;

    SET v_k = ROUND(LOG2(p_depth));
    IF POW(2, v_k) <> p_depth OR v_k < 1 OR v_k > 8 THEN
        SELECT 'ERR' AS 'RETURN', 'p_depth는 2의 거듭제곱(최대 256)이어야 합니다.' AS MSG;
    ELSEIF p_34 = 1 AND p_depth < 4 THEN
        SELECT 'ERR' AS 'RETURN', '3/4위전(p_34)은 참가 규모 4 이상에서 사용하세요.' AS MSG;
    ELSE
        IF p_points IS NULL OR p_points = '' THEN
            SET p_points = '3,2,1,1,1';
        END IF;

        START TRANSACTION;

        DELETE be FROM `bracket_entries` be
        INNER JOIN `brackets` b ON b.bracket_id = be.bracket_id
        INNER JOIN `bracket_groups` bg ON bg.group_id = b.group_id
        WHERE bg.event_id = p_event_id AND bg.bracket_type = 'SE';

        DELETE b FROM `brackets` b
        INNER JOIN `bracket_groups` bg ON bg.group_id = b.group_id
        WHERE bg.event_id = p_event_id AND bg.bracket_type = 'SE';

        DELETE FROM `bracket_groups`
        WHERE event_id = p_event_id AND bracket_type = 'SE';

        SET v_i = 1;
        WHILE v_i <= v_k DO
            SET v_rounds = POW(2, v_i);
            -- depth: 레거시와 동일 — 해당 라운드 «강» 인원수 (4인→4,2 / 8인→8,4,2 / 16인→16,8,4,2)
            SET v_u_depth = POW(2, v_i);

            SET v_ep = LOCATE(',', p_points, v_sp);
            SET v_pt = CAST(IF(v_ep > 0, SUBSTRING(p_points, v_sp, v_ep - v_sp), SUBSTRING(p_points, v_sp)) AS UNSIGNED);
            SET v_pt = IF(v_pt = 0, 1, v_pt);
            SET v_sp = IF(v_ep > 0, v_ep + 1, v_sp);

            INSERT INTO `bracket_groups` (event_id, depth, bracket_type, title, created_dt)
            VALUES (
                p_event_id,
                v_u_depth,
                'SE',
                CASE
                    WHEN v_rounds = p_depth THEN CONCAT('SE R1 (', v_rounds, '강)')
                    WHEN v_rounds = 2 AND p_34 = 1 THEN 'SE 결승 / 3·4위전'
                    WHEN v_rounds = 2 THEN 'SE 결승'
                    ELSE CONCAT('SE (', v_rounds, '강)')
                END,
                NOW()
            );
            SET v_gid = LAST_INSERT_ID();

            SET v_j = 1;
            IF v_rounds = 2 AND p_34 = 1 THEN
                INSERT INTO `brackets` (group_id, `order`, max_capacity, advance_count, match_point, status)
                VALUES (v_gid, 1, 2, 1, v_pt, 0), (v_gid, 2, 2, 1, v_pt, 0);
            ELSE
                WHILE v_j <= v_rounds / 2 DO
                    INSERT INTO `brackets` (group_id, `order`, max_capacity, advance_count, match_point, status)
                    VALUES (v_gid, v_j, 2, 1, v_pt, 0);
                    SET v_j = v_j + 1;
                END WHILE;
            END IF;

            SET v_i = v_i + 1;
        END WHILE;

        -- 승자 라우팅: 다음 라운드 조의 CEIL(order/2)
        UPDATE `brackets` b
        INNER JOIN `bracket_groups` bg_curr ON b.group_id = bg_curr.group_id
            AND bg_curr.event_id = p_event_id AND bg_curr.bracket_type = 'SE'
        INNER JOIN `bracket_groups` bg_next ON bg_next.event_id = p_event_id
            AND bg_next.bracket_type = 'SE' AND bg_next.depth = bg_curr.depth / 2
        INNER JOIN `brackets` b_next ON b_next.group_id = bg_next.group_id
            AND b_next.`order` = CEIL(b.`order` / 2)
        SET b.next_winner_bracket_id = b_next.bracket_id
        WHERE bg_curr.depth > 2;

        -- 3/4위전: 준결승(마지막 4강 스테이지) 패자 → 같은 결승 스테이지의 order=2
        IF p_34 = 1 THEN
            UPDATE `brackets` b
            INNER JOIN `bracket_groups` bg_curr ON b.group_id = bg_curr.group_id
                AND bg_curr.event_id = p_event_id AND bg_curr.bracket_type = 'SE'
            INNER JOIN `bracket_groups` bg_fin ON bg_fin.event_id = p_event_id
                AND bg_fin.bracket_type = 'SE' AND bg_fin.depth = 2
            INNER JOIN `brackets` b_tp ON b_tp.group_id = bg_fin.group_id AND b_tp.`order` = 2
            SET b.next_loser_bracket_id = b_tp.bracket_id
            WHERE bg_curr.depth = 4;
        END IF;

        SELECT COUNT(*) INTO v_ret FROM `brackets` b
        INNER JOIN `bracket_groups` bg ON b.group_id = bg.group_id
        WHERE bg.event_id = p_event_id AND bg.bracket_type = 'SE';

        IF v_ret > 0 THEN
            SELECT 'SUC' AS 'RETURN';
            COMMIT;
        ELSE
            SELECT 'ERR' AS 'RETURN', '브라켓 행이 생성되지 않았습니다.' AS MSG;
            ROLLBACK;
        END IF;
    END IF;
END//
DELIMITER ;

-- 프로시저 triumph.sp_bracket_single_select 구조 내보내기
DELIMITER //
CREATE PROCEDURE `sp_bracket_single_select`(
	IN `p_event_id` INT


)
BEGIN
    SELECT
    `bracket_id`,
	`event_id`,
	`depth`,
	`order`,
	`match_point`,
	`winner_entrant_id`,
	`status`,
	`created_at`,
	`updated_at`
    FROM brackets
    WHERE event_id = p_event_id;
END//
DELIMITER ;

-- 프로시저 triumph.sp_bracket_status_update 구조 내보내기
DELIMITER //
CREATE PROCEDURE `sp_bracket_status_update`(
    IN p_event_id INT,
    IN p_bracket_id BIGINT,
    IN p_status TINYINT
)
BEGIN
    DECLARE v_ret INT DEFAULT 0;
    DECLARE v_msg VARCHAR(32) DEFAULT 'SUC';

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'EXP' AS 'RETURN', 'sp_bracket_status_update failed' AS MSG;
    END;

    IF p_event_id IS NULL OR p_event_id <= 0
       OR p_bracket_id IS NULL OR p_bracket_id <= 0 THEN
        SET v_msg = 'ERR_INVALID';
    ELSEIF p_status IS NULL OR p_status < 0 OR p_status > 4 THEN
        SET v_msg = 'ERR_STATUS';
    ELSEIF NOT EXISTS (
        SELECT 1
        FROM `brackets` b
        INNER JOIN `bracket_groups` bg ON b.group_id = bg.group_id
        WHERE b.bracket_id = p_bracket_id AND bg.event_id = p_event_id
        LIMIT 1
    ) THEN
        SET v_msg = 'ERR_BRACKET';
    ELSE
        START TRANSACTION;
        UPDATE `brackets` b
        INNER JOIN `bracket_groups` bg ON b.group_id = bg.group_id
        SET b.`status` = p_status,
            b.update_dt = NOW()
        WHERE b.bracket_id = p_bracket_id
          AND bg.event_id = p_event_id;
        SET v_ret = ROW_COUNT();
        IF v_ret > 0 THEN
            COMMIT;
        ELSE
            ROLLBACK;
            SET v_msg = 'ERR';
        END IF;
    END IF;

    SELECT v_msg AS 'RETURN', v_ret AS affected_rows;
END//
DELIMITER ;

-- 프로시저 triumph.sp_bracket_winner_update 구조 내보내기
DELIMITER //
CREATE PROCEDURE `sp_bracket_winner_update`(
	IN `p_event_id` INT,
	IN `p_bracket_id` INT,
	IN `p_winner_id` INT
)
BEGIN
	DECLARE ret INT DEFAULT 0;
	DECLARE v_result_msg VARCHAR(100) DEFAULT 'ERR';
	
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
	BEGIN
		ROLLBACK;
		SELECT 'EXP' AS 'RETURN';
	END;
	
	-- bracket 및 participant 검증
	IF EXISTS (
		SELECT 1 FROM brackets b
		INNER JOIN bracket_groups bg ON b.group_id = bg.group_id
		INNER JOIN participants p ON bg.event_id = p.event_id
		WHERE bg.event_id = p_event_id
		AND b.bracket_id = p_bracket_id
		AND p.participant_id = p_winner_id
		LIMIT 1
	) THEN
		START TRANSACTION;

      UPDATE brackets
      SET winner_entrant_id = p_winner_id, `status` = 4, updated_at = NOW()
      WHERE bracket_id = p_bracket_id;

		SELECT ROW_COUNT() INTO ret;

		IF ret > 0 THEN
			COMMIT;
			SET v_result_msg = 'SUC';
		ELSE
			ROLLBACK;
			SET v_result_msg = 'ERR';
		END IF;
	ELSE
		SET v_result_msg = 'ERR_BRACKET';
	END IF;
	
	SELECT v_result_msg AS 'RETURN';

END//
DELIMITER ;

-- 프로시저 triumph.sp_chat_rooms_brackets_select 구조 내보내기
DELIMITER //
CREATE PROCEDURE `sp_chat_rooms_brackets_select`(
    IN `p_event_id` INT
)
    COMMENT '채팅방 + 브라켓 라운드 정렬 (통합: depth는 bracket_groups)'
BEGIN
    SELECT
        c.room_id,
        c.room_type,
        c.event_id,
        c.bracket_id,
        c.title,
        c.created_by,
        c.is_deleted,
        c.created_dt,
        c.updated_dt,
        c.closed_dt,
        bg.depth,
        b.`order`,
        b.status,
        CASE
            WHEN bg.depth IS NULL THEN 999999
            ELSE bg.depth
        END AS sort_depth
    FROM `chat_rooms` c
    LEFT JOIN `brackets` b ON c.bracket_id = b.bracket_id
    LEFT JOIN `bracket_groups` bg ON b.group_id = bg.group_id
    WHERE c.event_id = p_event_id
      AND c.is_deleted = 0
    ORDER BY
        CASE WHEN bg.depth IS NULL THEN 1 ELSE 0 END,
        bg.depth DESC,
        b.`order` ASC;
END//
DELIMITER ;

-- 프로시저 triumph._sp_brackets_update_auto_judge 구조 내보내기
DELIMITER //
CREATE PROCEDURE `_sp_brackets_update_auto_judge`(
	IN `p_event_id` INT(11),
	IN `p_depth` INT(11),
	IN `p_auto_judge` TINYINT
)
BEGIN


	DECLARE ret INT DEFAULT 0;

	
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
	BEGIN
		SELECT 'EXP' AS 'RETURN';
	END;

	
	IF (p_event_id IS NULL OR p_depth IS NULL OR p_auto_judge IS NULL) THEN
		SELECT 'ERR' AS 'RETURN';
	ELSE
		
		UPDATE brackets
		SET auto_judge = p_auto_judge, updated_at = NOW()
		WHERE event_id = p_event_id AND depth = p_depth;
	
		SELECT ROW_COUNT() INTO ret;
	END IF;

	IF ret > 0 THEN
		SELECT 'SUC' AS 'RETURN';
	ELSE
		SELECT 'ERR' AS 'RETURN';
	END IF;

END//
DELIMITER ;

-- 프로시저 triumph._sp_bracket_groups_enable 구조 내보내기
DELIMITER //
CREATE PROCEDURE `_sp_bracket_groups_enable`(
	IN `p_event_id` INT
)
BEGIN
DECLARE done INT DEFAULT FALSE;
DECLARE v_round INT ;
DECLARE v_i INT ;
DECLARE v_second INT;

    DECLARE cur_rounds CURSOR FOR
    SELECT DISTINCT b.depth fROM `events` e INNER JOIN brackets b ON e.event_id = b.event_id WHERE e.event_id = p_event_id;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
        
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'EXP' AS 'RETURN';
    END;
    
    SET v_second = 60;

    OPEN cur_rounds;
    read_loop : LOOP 
	 FETCH cur_rounds INTO v_round;
	 
	 if done then
	 leave read_loop;
	 END if;
	 
	 CALL `sp_bracket_groups_insert`(p_event_id, v_round, DATE_ADD(NOW(), INTERVAL v_second SECOND), 1);
	 
	 SET v_second = v_second + 60;
	 
    END LOOP;
    
    close cur_rounds;
    
    if (SELECT COUNT(*) FROM bracket_groups bg WHERE bg.event_id = p_event_id) > 0 then
    SELECT 'SUC' AS 'RETURN';
    END if;

END//
DELIMITER ;

-- 프로시저 triumph._sp_events_bracket_participants_init 구조 내보내기
DELIMITER //
CREATE PROCEDURE `_sp_events_bracket_participants_init`(
	IN `p_event_id` INT
)
BEGIN
DELETE bs
FROM triumph.brackets b
LEFT OUTER JOIN bracket_entries be ON b.bracket_id = be.bracket_id
LEFT OUTER JOIN bracket_sets bs ON be.bracket_id = bs.bracket_id 
WHERE b.event_id = p_event_id;


DELETE be
FROM triumph.brackets b
LEFT OUTER JOIN bracket_entries be ON b.bracket_id = be.bracket_id
WHERE b.event_id = p_event_id;


UPDATE triumph.brackets b
SET b.winner_entrant_id = 0, b.`status` = 0
WHERE b.event_id = p_event_id;

SELECT 'SUC' AS 'RETURN';
END//
DELIMITER ;

-- 프로시저 triumph._sp_participants_bracket_sets_select 구조 내보내기
DELIMITER //
CREATE PROCEDURE `_sp_participants_bracket_sets_select`(
	IN `p_participant_id` INT
)
BEGIN
    SELECT 
        p.participant_id,
        p.entrant_id,
        p.entrant_name,
        p.entrant_image_url,
        p.dummy,
        SUM(CASE WHEN bs.winlose = 1 THEN 1 ELSE 0 END) AS winCount,
        SUM(CASE WHEN bs.winlose = 0 THEN 1 ELSE 0 END) AS loseCount
    FROM participants p
    JOIN bracket_sets bs 
        ON p.participant_id = bs.participant_id
    WHERE FIND_IN_SET(p.participant_id, p_participant_id) > 0
    GROUP BY 
        p.participant_id, 
        p.entrant_id, 
        p.entrant_name, 
        p.entrant_image_url, 
        p.dummy;
END//
DELIMITER ;

-- 프로시저 triumph._sp_participant_bracket_set_select 구조 내보내기
DELIMITER //
CREATE PROCEDURE `_sp_participant_bracket_set_select`(
	IN `p_member_id` INT
)
BEGIN
    SELECT
            p.participant_id,
            p.entrant_id,
            p.entrant_name,
            p.entrant_image_url,
            p.dummy,
            SUM(CASE WHEN bs.winlose = 1 THEN 1 ELSE 0 END) AS winCount,
            SUM(CASE WHEN bs.winlose = 0 THEN 1 ELSE 0 END) AS loseCount
        FROM participants p
        INNER JOIN bracket_sets bs 
            ON p.participant_id = bs.participant_id
        WHERE p.participant_id = p_member_id
        GROUP BY 
            p.participant_id, 
            p.entrant_id, 
            p.entrant_name, 
            p.entrant_image_url, 
            p.dummy;
END//
DELIMITER ;

-- 프로시저 triumph._sp_reset_bracket_judgment_v2 구조 내보내기
DELIMITER //
CREATE PROCEDURE `_sp_reset_bracket_judgment_v2`(
	IN `p_event_id` INT,
	IN `p_bracket_id` BIGINT
)
BEGIN
    
    DECLARE v_depth INT;
    DECLARE v_order INT;
    DECLARE v_winner_id INT;
    DECLARE v_loser_id INT DEFAULT 0;
    DECLARE v_current_status TINYINT;
    
    DECLARE v_next_bracket_id BIGINT DEFAULT NULL;
    DECLARE v_next_status TINYINT DEFAULT 0;
    DECLARE v_third_bracket_id BIGINT DEFAULT NULL;
    DECLARE v_third_status TINYINT DEFAULT 0;
    
    DECLARE v_can_proceed TINYINT DEFAULT 1; 
    DECLARE v_result_msg VARCHAR(100) DEFAULT 'SUCCESS';

    
    SELECT depth, `order`, winner_entrant_id, status 
    INTO v_depth, v_order, v_winner_id, v_current_status
    FROM brackets 
    WHERE bracket_id = p_bracket_id AND event_id = p_event_id;

    
    IF v_current_status != 4 OR v_winner_id = 0 THEN
        SET v_can_proceed = 0;
        SET v_result_msg = 'ERROR: 판정 완료된 경기가 아닙니다.';
    END IF;

    
    IF v_can_proceed = 1 THEN
        
        IF v_depth > 2 AND v_depth != 3 THEN
            BEGIN
                DECLARE v_next_depth INT;
                DECLARE v_next_order INT;
                
                SET v_next_depth = IF(v_depth = 4, 2, v_depth / 2);
                SET v_next_order = CEIL(v_order / 2);

                SELECT bracket_id, status INTO v_next_bracket_id, v_next_status 
                FROM brackets 
                WHERE event_id = p_event_id AND depth = v_next_depth AND `order` = v_next_order;

                
                IF v_next_bracket_id IS NOT NULL AND v_next_status > 0 THEN
                    SET v_can_proceed = 0;
                    SET v_result_msg = 'ERROR: 다음 라운드 경기가 진행 중입니다.';
                END IF;
            END;
        END IF;
    END IF;

    
    IF v_can_proceed = 1 AND v_depth = 4 THEN
        BEGIN
            SELECT bracket_id, status INTO v_third_bracket_id, v_third_status 
            FROM brackets 
            WHERE event_id = p_event_id AND depth = 3 AND `order` = 1;

            IF v_third_bracket_id IS NOT NULL AND v_third_status > 0 THEN
                SET v_can_proceed = 0;
                SET v_result_msg = 'ERROR: 3/4위전 경기가 진행 중입니다.';
            END IF;
        END;
    END IF;

    
    IF v_can_proceed = 1 THEN
        START TRANSACTION;

        
        SELECT participant_id INTO v_loser_id 
        FROM bracket_entries 
        WHERE bracket_id = p_bracket_id AND participant_id != v_winner_id LIMIT 1;

        
        IF v_next_bracket_id IS NOT NULL THEN
            DELETE FROM bracket_entries 
            WHERE bracket_id = v_next_bracket_id AND participant_id = v_winner_id;
        END IF;

        
        IF v_third_bracket_id IS NOT NULL AND v_loser_id != 0 THEN
            DELETE FROM bracket_entries 
            WHERE bracket_id = v_third_bracket_id AND participant_id = v_loser_id;
        END IF;

        
        UPDATE brackets 
        SET winner_entrant_id = 0,
            status = 1,
            match_end_dt = NULL,
            updated_at = NOW()
        WHERE bracket_id = p_bracket_id;

        
        UPDATE bracket_entries 
        SET score = 0,
            status = 0,
            updated_at = NOW()
        WHERE bracket_id = p_bracket_id;

        COMMIT;
    END IF;

    
    SELECT v_result_msg AS message;

END//
DELIMITER ;

/*!40103 SET TIME_ZONE=IFNULL(@OLD_TIME_ZONE, 'system') */;
/*!40101 SET SQL_MODE=IFNULL(@OLD_SQL_MODE, '') */;
/*!40014 SET FOREIGN_KEY_CHECKS=IFNULL(@OLD_FOREIGN_KEY_CHECKS, 1) */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40111 SET SQL_NOTES=IFNULL(@OLD_SQL_NOTES, 1) */;
