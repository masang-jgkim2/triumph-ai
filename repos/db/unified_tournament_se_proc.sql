USE triumph;
DELIMITER $$

-- ============================================================
-- 통합 스키마 전용 — SE 프로시저 번들
-- bracket_groups / brackets (group_id) 구조
-- 단독 배포본: schema/sp_*.sql (레거시 QA용 adjudge_* 는 event_id 버전 별도)
--
-- [본 파일 포함 SP — 8종 + 기존 SE/채팅 유틸]
--   §3  sp_bracket_adjudge_auto
--   §4  sp_bracket_adjudge_reset
--   §6  sp_bracket_entries_participants_members_select
--   §12 sp_bracket_status_update
--   §13 sp_bracket_winner_update
--   §14 sp_chat_room_member_insert
--   §15 sp_chat_room_update_all
--   §16 sp_event_participants_select
-- ============================================================

-- ============================================================
-- 1) SE 브라켓 생성
-- bracket_groups + brackets + 승자/패자 라우팅
-- 파라미터: p_event_id, p_depth(참가 규모 2^n, 최대 256), p_34(3/4위전 0/1), p_points(BO CSV)
-- 사용 예제: CALL sp_bracket_single_insert(1001, 8, 0, '3,2,1,1');
-- ============================================================
DROP PROCEDURE IF EXISTS `sp_bracket_single_insert`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_bracket_single_insert`(
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
END$$


-- ============================================================
-- 2) SE 1라운드 참가자 배치
-- p_depth 라운드(bracket_groups.depth)에 CSV 순서대로 2명씩 배정
-- 파라미터: p_event_id, p_depth(1라운드 depth=참가 규모), p_entries(participant_id CSV)
-- 사용 예제: CALL sp_bracket_entries_single_insert(1001, 8, '101,102,103,104,105,106,107,108');
-- ============================================================
DROP PROCEDURE IF EXISTS `sp_bracket_entries_single_insert`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_bracket_entries_single_insert`(
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
END$$


-- ============================================================
-- 3) SE 자동 판정 (스케줄러용)
-- auto_judge=1 SE 그룹 중 판정 조건 충족 매치만 처리
-- 참가자별 winlose 합=match_point, LIMIT 128
-- 대회 종료: event_cleanup_auto 미사용 → SE 전 경기 status>=3 시 events.status=3 즉시 반영
-- 파라미터: p_event_id (0/NULL이면 auto_judge=1 SE 전체 이벤트)
-- 사용 예제: CALL sp_bracket_adjudge_auto(1001);
-- ============================================================
DROP PROCEDURE IF EXISTS `sp_bracket_adjudge_auto`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_bracket_adjudge_auto`(IN p_event_id INT)
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
END$$


-- ============================================================
-- 4) SE 판정 롤백
-- 완료된 매치를 대기 상태로 되돌리고 다음 라운드 진출 엔트리 제거
-- next_winner/loser_bracket_id 기준, 채팅 closed_dt 롤백(legacy)
-- 파라미터: p_event_id, p_depth(bracket_groups.depth), p_order, p_set_init(1이면 bracket_sets 삭제)
-- 사용 예제: CALL sp_bracket_adjudge_reset(1001, 4, 1, 1);
-- ============================================================
DROP PROCEDURE IF EXISTS `sp_bracket_adjudge_reset`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_bracket_adjudge_reset`(
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
END$$


-- ============================================================
-- 5) SE/DE 랜덤 세트 생성 (테스트/시뮬레이션용)
-- 미진행 매치에 bracket_sets 생성 후 엔트리/브라켓 status=2
-- 파라미터: p_event_id(0/NULL=전체), p_force(1=전원 대상), p_player_win(1=유저 승 우선)
-- 사용 예제: CALL sp_bracket_score_auto(1001, 0, 0);
-- ============================================================
DROP PROCEDURE IF EXISTS `sp_bracket_score_auto`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_bracket_score_auto`(
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
END$$

DELIMITER ;

-- ============================================================
-- 아래: 통합 스키마(brackets에 event_id/depth 없음) 대응 SELECT 프로시저
-- 기존 1054: Unknown column 'b.depth' / 'br.event_id' 등
-- ============================================================
DELIMITER $$

-- ============================================================
-- 6) 매치별 참가자·팀원·운영자 조회 (통합 스키마)
-- legacy 대비: depth는 bracket_groups, event는 bg.event_id 경유
-- 파라미터: p_event_id, p_bracket_id
-- 사용 예제: CALL sp_bracket_entries_participants_members_select(1001, 50001);
-- ============================================================
DROP PROCEDURE IF EXISTS `sp_bracket_entries_participants_members_select`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_bracket_entries_participants_members_select`(
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
END$$


-- ============================================================
-- 7) 이벤트별 브라켓·엔트리·참가자 조회
-- 레거시 결과셋 컬럼 호환 (통합 스키마: depth는 bracket_groups)
-- 파라미터: p_event_id
-- 사용 예제: CALL sp_bracket_entries_groups_participants_select(1001);
-- ============================================================
DROP PROCEDURE IF EXISTS `sp_bracket_entries_groups_participants_select`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_bracket_entries_groups_participants_select`(
    IN `p_event_id` INT
)
LANGUAGE SQL
NOT DETERMINISTIC
CONTAINS SQL
SQL SECURITY DEFINER
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
    -- 레거시와 동일한 결과 컬럼 세트 + bracket_type/group_title/라우팅 ID
    -- SE만 노출: 해당 이벤트에 SE 매치(bracket)가 있을 때. 없으면 전 타입 노출.
    SELECT
        br.bracket_id,
        bg.event_id,
        br.group_id,
        bg.bracket_type,
        bg.title AS group_title,
        bg.depth,
        br.`order`,
        br.match_point,
        br.start_dt,
        br.winner_entrant_id,
        br.next_winner_bracket_id,
        br.next_loser_bracket_id,
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
END$$

-- ============================================================
-- 8) 채팅방 + 브라켓 라운드 조회
-- chat_rooms와 brackets/bracket_groups depth·order 정렬
-- 파라미터: p_event_id
-- 사용 예제: CALL sp_chat_rooms_brackets_select(1001);
-- ============================================================
DROP PROCEDURE IF EXISTS `sp_chat_rooms_brackets_select`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_chat_rooms_brackets_select`(
    IN `p_event_id` INT
)
LANGUAGE SQL
NOT DETERMINISTIC
CONTAINS SQL
SQL SECURITY DEFINER
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
END$$

-- ============================================================
-- 9) 채팅방 생성 (통합: SE 브라켓은 group_id·bracket_groups)
-- NOTICE/ADMIN/LOBBY: 단일 방 + 주최자 OWNER 멤버
-- MATCH: 해당 이벤트 SE 매치별 방 재생성(기존 MATCH 방·멤버 삭제 후 삽입)
-- 파라미터: p_event_id, p_member_id(대회 주최 events.member_id와 일치해야 함), p_room_type, p_room_name(선택)
-- 사용 예제: CALL sp_chat_room_insert(1001, 250, 'LOBBY', '유저 채널');
-- ============================================================
DROP PROCEDURE IF EXISTS `sp_chat_room_insert`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_chat_room_insert`(
    IN p_event_id INT,
    IN p_member_id INT,
    IN p_room_type ENUM('ADMIN', 'NOTICE', 'LOBBY', 'MATCH', 'DM'),
    IN p_room_name VARCHAR(512)
)
BEGIN
    DECLARE v_host_member_id INT DEFAULT NULL;
    DECLARE v_team_size TINYINT DEFAULT 0;
    DECLARE v_room_id INT DEFAULT 0;
    DECLARE v_room_name VARCHAR(255) DEFAULT '';
    DECLARE v_title VARCHAR(255) DEFAULT '';
    DECLARE v_now DATETIME DEFAULT NOW();
    DECLARE v_rows_inserted INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        DROP TEMPORARY TABLE IF EXISTS tmp_chat_room_name;
        DROP TEMPORARY TABLE IF EXISTS tmp_manager;
        DROP TEMPORARY TABLE IF EXISTS tmp_user;
        SELECT 'EXP' AS 'RETURN';
    END;

    IF p_event_id IS NULL OR p_event_id <= 0 OR p_member_id IS NULL OR p_member_id <= 0 THEN
        SELECT 'ERR' AS 'RETURN', 'event_id·member_id가 유효하지 않습니다.' AS MSG;
    ELSEIF p_room_type = 'DM' THEN
        SELECT 'ERR' AS 'RETURN', 'DM room_type은 미지원입니다.' AS MSG;
    ELSE
        SELECT e.member_id, e.team_size
          INTO v_host_member_id, v_team_size
        FROM `events` AS e
        WHERE e.event_id = p_event_id
        LIMIT 1;

        IF v_host_member_id IS NULL THEN
            SELECT 'ERR' AS 'RETURN', '이벤트를 찾을 수 없습니다.' AS MSG;
        ELSEIF v_host_member_id <> p_member_id THEN
            SELECT 'ERR' AS 'RETURN', '대회 주최자(member_id)만 채팅방을 생성할 수 있습니다.' AS MSG;
        ELSEIF IFNULL(v_team_size, 0) < 1 THEN
            SELECT 'ERR' AS 'RETURN', 'team_size가 유효하지 않습니다.' AS MSG;
        ELSE
            DROP TEMPORARY TABLE IF EXISTS tmp_chat_room_name;
            CREATE TEMPORARY TABLE tmp_chat_room_name (
                room_orders INT AUTO_INCREMENT PRIMARY KEY,
                room_type ENUM('ADMIN', 'NOTICE', 'LOBBY', 'MATCH', 'DM') NOT NULL,
                room_name VARCHAR(255) NULL,
                created_dt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_dt DATETIME NULL
            ) ENGINE=InnoDB;

            INSERT INTO tmp_chat_room_name (room_type, room_name) VALUES
                ('NOTICE', NULL),
                ('ADMIN', NULL),
                ('LOBBY', NULL),
                ('MATCH', NULL);

            IF p_room_name IS NOT NULL AND TRIM(p_room_name) <> '' THEN
                UPDATE tmp_chat_room_name AS t
                SET t.room_name = TRIM(p_room_name)
                WHERE t.room_type = p_room_type;
            END IF;

            START TRANSACTION;

            DROP TEMPORARY TABLE IF EXISTS tmp_manager;
            CREATE TEMPORARY TABLE tmp_manager (
                seq INT AUTO_INCREMENT PRIMARY KEY,
                event_id INT,
                member_id INT,
                nickname VARCHAR(255),
                image_url VARCHAR(512),
                role ENUM(
                    'OWNER', 'MANAGER', 'MEMBER', 'TEAM_LEADER', 'TEAM_MEMBER',
                    'A TEAM_LEADER', 'A TEAM_MEMBER', 'B TEAM_LEADER', 'B TEAM_MEMBER', 'GUEST'
                ) NOT NULL DEFAULT 'MANAGER'
            ) ENGINE=InnoDB;

            INSERT INTO tmp_manager (event_id, member_id, nickname, image_url, role)
            SELECT p_event_id, m.member_id, m.name, m.image_url, 'OWNER'
            FROM `members` AS m
            WHERE m.member_id = v_host_member_id
            LIMIT 1;

            IF p_room_type IN ('NOTICE', 'ADMIN', 'LOBBY') THEN
                SELECT t.room_name INTO v_title
                FROM tmp_chat_room_name AS t
                WHERE t.room_type = p_room_type
                LIMIT 1;

                IF v_title IS NULL OR TRIM(v_title) = '' THEN
                    SET v_title = CASE p_room_type
                        WHEN 'NOTICE' THEN '공지'
                        WHEN 'ADMIN' THEN '관리'
                        ELSE '유저 채널'
                    END;
                END IF;

                INSERT INTO `chat_rooms` (
                    room_type, event_id, bracket_id, title, created_by, is_deleted, created_dt
                ) VALUES (
                    p_room_type, p_event_id, NULL, v_title, v_host_member_id, 0, v_now
                );

                SET v_room_id = LAST_INSERT_ID();

                INSERT INTO `chat_members` (room_id, member_id, nickname, image_url, role)
                SELECT v_room_id, tm.member_id, tm.nickname, tm.image_url, tm.role
                FROM tmp_manager AS tm
                WHERE tm.role = 'OWNER';

                SET v_rows_inserted = ROW_COUNT();

            ELSEIF p_room_type = 'MATCH' THEN
                DELETE cm
                FROM `chat_members` AS cm
                INNER JOIN `chat_rooms` AS cr ON cr.room_id = cm.room_id
                WHERE cr.event_id = p_event_id
                  AND cr.room_type = 'MATCH';

                DELETE FROM `chat_rooms`
                WHERE event_id = p_event_id
                  AND room_type = 'MATCH';

                DROP TEMPORARY TABLE IF EXISTS tmp_user;
                CREATE TEMPORARY TABLE tmp_user (
                    seq INT AUTO_INCREMENT PRIMARY KEY,
                    bracket_id BIGINT,
                    event_id INT,
                    depth INT,
                    `order` INT,
                    participant_id INT,
                    nickname VARCHAR(255),
                    image_url VARCHAR(512),
                    role ENUM(
                        'OWNER', 'MANAGER', 'MEMBER', 'TEAM_LEADER', 'TEAM_MEMBER', 'GUEST'
                    ) NOT NULL DEFAULT 'GUEST'
                ) ENGINE=InnoDB;

                INSERT INTO tmp_user (bracket_id, event_id, depth, `order`, participant_id, nickname, image_url, role)
                SELECT
                    b.bracket_id,
                    bg.event_id,
                    bg.depth,
                    b.`order`,
                    be.participant_id,
                    COALESCE(pm.member_name, p.entrant_name, '') AS nickname,
                    COALESCE(pm.member_image_url, p.entrant_image_url) AS image_url,
                    'MEMBER'
                FROM `brackets` AS b
                INNER JOIN `bracket_groups` AS bg
                    ON bg.group_id = b.group_id
                   AND bg.event_id = p_event_id
                   AND bg.bracket_type = 'SE'
                LEFT JOIN `bracket_entries` AS be ON be.bracket_id = b.bracket_id
                LEFT JOIN `participants` AS p ON p.participant_id = be.participant_id
                LEFT JOIN `participant_members` AS pm
                    ON pm.participant_id = p.participant_id AND pm.role = 'LEADER';

                SELECT t.room_name INTO v_room_name
                FROM tmp_chat_room_name AS t
                WHERE t.room_type = p_room_type
                LIMIT 1;

                INSERT INTO `chat_rooms` (
                    room_type, event_id, bracket_id, title, created_by, is_deleted, created_dt
                )
                SELECT
                    p_room_type,
                    tu.event_id,
                    tu.bracket_id,
                    CONCAT(
                        IFNULL(NULLIF(TRIM(v_room_name), ''), '경기 채널'),
                        tu.depth,
                        '-',
                        tu.`order`,
                        '-',
                        tu.bracket_id
                    ),
                    v_host_member_id,
                    0,
                    v_now
                FROM (
                    SELECT DISTINCT
                        u.bracket_id,
                        u.event_id,
                        u.depth,
                        u.`order`
                    FROM tmp_user AS u
                ) AS tu;

                SET v_rows_inserted = ROW_COUNT();

                INSERT INTO `chat_members` (room_id, member_id, nickname, image_url, role)
                SELECT cr.room_id, tm.member_id, tm.nickname, tm.image_url, tm.role
                FROM tmp_manager AS tm
                INNER JOIN `chat_rooms` AS cr
                    ON cr.event_id = p_event_id
                   AND cr.room_type = 'MATCH'
                WHERE tm.role = 'OWNER';
            END IF;

            IF v_rows_inserted > 0 THEN
                COMMIT;
                SELECT 'SUC' AS 'RETURN';
            ELSE
                ROLLBACK;
                SELECT 'ERR' AS 'RETURN', '생성된 채팅방이 없습니다.' AS MSG;
            END IF;

            DROP TEMPORARY TABLE IF EXISTS tmp_chat_room_name;
            DROP TEMPORARY TABLE IF EXISTS tmp_manager;
            DROP TEMPORARY TABLE IF EXISTS tmp_user;
        END IF;
    END IF;
END$$

-- ============================================================
-- 10) SE 라운드 메타 생성
-- bracket_groups 행 생성 (통합: bracket_type=SE)
-- 파라미터: p_event_id, p_depth(SE bracket_groups.depth), p_start_dt, p_auto_judge
-- 사용 예제: CALL sp_bracket_groups_insert(1001, 8, '2026-05-12 18:00:00', 1);
-- ============================================================
DROP PROCEDURE IF EXISTS `sp_bracket_groups_insert`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_bracket_groups_insert`(
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
END$$

-- ============================================================
-- 11) SE 라운드 메타 갱신
-- bracket_groups.start_dt / auto_judge 갱신 (통합: bracket_type=SE)
-- 파라미터: p_event_id, p_depth(SE bracket_groups.depth), p_start_dt, p_auto_judge
-- 사용 예제: CALL sp_bracket_groups_update(1001, 8, '2026-05-12 18:00:00', 1);
-- ============================================================
DROP PROCEDURE IF EXISTS `sp_bracket_groups_update`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_bracket_groups_update`(
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
END$$


-- ============================================================
-- 12) 브라켓 status 변경 (통합)
-- 파라미터: p_event_id, p_bracket_id, p_status(0~4)
-- 사용 예제: CALL sp_bracket_status_update(1001, 50001, 2);
-- ============================================================
DROP PROCEDURE IF EXISTS `sp_bracket_status_update`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_bracket_status_update`(
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
END$$


-- ============================================================
-- 13) 수동 승자 지정 (통합: participants·bracket_groups 검증, status=4)
-- 단독: schema/sp_bracket_winner_update.sql
-- 사용 예제: CALL sp_bracket_winner_update(1001, 50001, 2001);
-- ============================================================
DROP PROCEDURE IF EXISTS `sp_bracket_winner_update`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_bracket_winner_update`(
    IN p_event_id INT,
    IN p_bracket_id BIGINT,
    IN p_winner_id INT
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
        SELECT 1
        FROM `brackets` b
        INNER JOIN `bracket_groups` bg ON b.group_id = bg.group_id
        INNER JOIN `participants` p ON bg.event_id = p.event_id
        WHERE bg.event_id = p_event_id
          AND b.bracket_id = p_bracket_id
          AND p.participant_id = p_winner_id
        LIMIT 1
    ) THEN
        START TRANSACTION;

        UPDATE `brackets`
        SET winner_entrant_id = p_winner_id,
            `status` = 4,
            updated_at = NOW()
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
END$$


-- ============================================================
-- 14) 채팅방 멤버 동기화 (통합, review §6 반영)
-- p_bracket_id NULL=이벤트 전체 MATCH, NOT NULL=해당 매치
-- 사용 예제: CALL sp_chat_room_member_insert(1001, 10, 'MATCH', NULL);
-- ============================================================
DROP PROCEDURE IF EXISTS `sp_chat_room_member_insert`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_chat_room_member_insert`(
    IN p_event_id INT,
    IN p_member_id INT,
    IN p_room_type ENUM('ADMIN', 'NOTICE', 'LOBBY', 'MATCH', 'DM'),
    IN p_bracket_id BIGINT
)
BEGIN
    DECLARE v_host_id INT DEFAULT NULL;
    DECLARE v_team_size TINYINT DEFAULT 0;
    DECLARE v_rows INT DEFAULT 0;
    DECLARE v_now DATETIME DEFAULT NOW();

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        DROP TEMPORARY TABLE IF EXISTS tmp_chat_sync_user;
        SELECT 'EXP' AS 'RETURN', 'sp_chat_room_member_insert failed' AS MSG;
    END;

    IF p_event_id IS NULL OR p_event_id <= 0 OR p_member_id IS NULL OR p_member_id <= 0 THEN
        SELECT 'ERR' AS 'RETURN', 'event_id·member_id가 유효하지 않습니다.' AS MSG;
    ELSEIF p_room_type = 'DM' THEN
        SELECT 'ERR' AS 'RETURN', 'DM room_type은 미지원입니다.' AS MSG;
    ELSE
        SELECT e.member_id, e.team_size
        INTO v_host_id, v_team_size
        FROM `events` e
        WHERE e.event_id = p_event_id
        LIMIT 1;

        IF v_host_id IS NULL THEN
            SELECT 'ERR' AS 'RETURN', '이벤트를 찾을 수 없습니다.' AS MSG;
        ELSEIF v_host_id <> p_member_id THEN
            SELECT 'ERR' AS 'RETURN', '대회 주최자만 멤버 동기화를 실행할 수 있습니다.' AS MSG;
        ELSEIF IFNULL(v_team_size, 0) < 1 THEN
            SELECT 'ERR' AS 'RETURN', 'team_size가 유효하지 않습니다.' AS MSG;
        ELSE
            DROP TEMPORARY TABLE IF EXISTS tmp_chat_sync_user;
            CREATE TEMPORARY TABLE tmp_chat_sync_user (
                bracket_id BIGINT NULL,
                event_id INT NOT NULL,
                participant_id INT UNSIGNED NOT NULL,
                chat_member_id INT NOT NULL,
                nickname VARCHAR(255) NOT NULL,
                image_url VARCHAR(512) NULL,
                role ENUM(
                    'OWNER','MANAGER','MEMBER','TEAM_LEADER','TEAM_MEMBER',
                    'A TEAM_LEADER','A TEAM_MEMBER','B TEAM_LEADER','B TEAM_MEMBER','GUEST'
                ) NOT NULL DEFAULT 'MEMBER',
                dummy TINYINT NOT NULL DEFAULT 0,
                PRIMARY KEY (participant_id, chat_member_id)
            ) ENGINE=InnoDB;

            IF IFNULL(v_team_size, 0) = 1 THEN
                INSERT INTO tmp_chat_sync_user (
                    bracket_id, event_id, participant_id, chat_member_id, nickname, image_url, role, dummy
                )
                SELECT
                    b.bracket_id, bg.event_id, be.participant_id,
                    IFNULL(p.entrant_id, 0), p.entrant_name, p.entrant_image_url, 'MEMBER', p.dummy
                FROM `brackets` b
                INNER JOIN `bracket_groups` bg ON b.group_id = bg.group_id
                INNER JOIN `bracket_entries` be ON b.bracket_id = be.bracket_id
                INNER JOIN `participants` p ON be.participant_id = p.participant_id
                WHERE bg.event_id = p_event_id
                  AND (p_bracket_id IS NULL OR b.bracket_id = p_bracket_id)
                  AND IFNULL(p.entrant_id, 0) > 0
                  AND p.dummy = 0;
            ELSE
                INSERT INTO tmp_chat_sync_user (
                    bracket_id, event_id, participant_id, chat_member_id, nickname, image_url, role, dummy
                )
                SELECT
                    b.bracket_id, bg.event_id, be.participant_id,
                    pm.member_id, pm.member_name, pm.member_image_url,
                    CASE pm.role WHEN 'LEADER' THEN 'TEAM_LEADER' ELSE 'TEAM_MEMBER' END,
                    pm.dummy
                FROM `brackets` b
                INNER JOIN `bracket_groups` bg ON b.group_id = bg.group_id
                INNER JOIN `bracket_entries` be ON b.bracket_id = be.bracket_id
                INNER JOIN `participants` p ON be.participant_id = p.participant_id
                INNER JOIN `participant_members` pm ON p.participant_id = pm.participant_id
                WHERE bg.event_id = p_event_id
                  AND (p_bracket_id IS NULL OR b.bracket_id = p_bracket_id)
                  AND pm.member_id IS NOT NULL AND pm.member_id > 0
                  AND pm.dummy = 0 AND p.dummy = 0;
            END IF;

            START TRANSACTION;

            IF p_room_type IN ('NOTICE', 'LOBBY') THEN
                INSERT IGNORE INTO `chat_members` (room_id, member_id, nickname, image_url, role, last_read_dt)
                SELECT DISTINCT cr.room_id, t.chat_member_id, t.nickname, t.image_url, t.role, v_now
                FROM `chat_rooms` cr
                INNER JOIN tmp_chat_sync_user t ON cr.event_id = t.event_id
                WHERE cr.room_type = p_room_type
                  AND cr.event_id = p_event_id
                  AND cr.is_deleted = 0;
            ELSEIF p_room_type = 'MATCH' THEN
                INSERT IGNORE INTO `chat_members` (room_id, member_id, nickname, image_url, role, last_read_dt)
                SELECT DISTINCT cr.room_id, t.chat_member_id, t.nickname, t.image_url, t.role, v_now
                FROM `chat_rooms` cr
                INNER JOIN tmp_chat_sync_user t
                  ON cr.event_id = t.event_id AND cr.bracket_id = t.bracket_id
                WHERE cr.room_type = 'MATCH'
                  AND cr.event_id = p_event_id
                  AND cr.is_deleted = 0
                  AND (p_bracket_id IS NULL OR cr.bracket_id = p_bracket_id);
            END IF;

            SET v_rows = ROW_COUNT();
            IF v_rows >= 0 THEN
                COMMIT;
                SELECT 'SUC' AS 'RETURN', v_rows AS inserted_rows;
            ELSE
                ROLLBACK;
                SELECT 'ERR' AS 'RETURN', '멤버 삽입 실패' AS MSG;
            END IF;

            DROP TEMPORARY TABLE IF EXISTS tmp_chat_sync_user;
        END IF;
    END IF;
END$$


-- ============================================================
-- 15) 채팅방 일괄 종료 예약 (통합, review §7: status < 3)
-- 사용 예제: CALL sp_chat_room_update_all(1001, 10);
-- ============================================================
DROP PROCEDURE IF EXISTS `sp_chat_room_update_all`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_chat_room_update_all`(
    IN p_event_id INT,
    IN p_member_id INT
)
BEGIN
    DECLARE v_ret INT DEFAULT 0;
    DECLARE v_room_cnt INT DEFAULT 0;
    DECLARE v_open_bracket_cnt INT DEFAULT 0;
    DECLARE v_host_id INT DEFAULT NULL;
    DECLARE v_msg VARCHAR(32) DEFAULT 'SUC';

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'EXP' AS 'RETURN', 'sp_chat_room_update_all failed' AS MSG;
    END;

    SELECT e.member_id INTO v_host_id FROM `events` e WHERE e.event_id = p_event_id LIMIT 1;

    IF v_host_id IS NULL THEN
        SET v_msg = 'ERR_EVENT';
    ELSEIF v_host_id <> p_member_id THEN
        SET v_msg = 'ERR_MANAGER';
    ELSE
        SELECT COUNT(*) INTO v_open_bracket_cnt
        FROM `brackets` b
        INNER JOIN `bracket_groups` bg ON b.group_id = bg.group_id
        WHERE bg.event_id = p_event_id
          AND bg.bracket_type IN ('SE', 'DE_WB', 'DE_LB', 'DE_GF')
          AND b.`status` < 3;

        IF v_open_bracket_cnt > 0 THEN
            SET v_msg = 'ERR_BRACKET';
        ELSE
            SELECT COUNT(*) INTO v_room_cnt
            FROM `chat_rooms` cr
            WHERE cr.event_id = p_event_id AND cr.is_deleted = 0;

            START TRANSACTION;
            UPDATE `chat_rooms` cr
            SET cr.closed_dt = DATE_ADD(NOW(), INTERVAL 7 DAY),
                cr.updated_dt = NOW()
            WHERE cr.event_id = p_event_id AND cr.is_deleted = 0;
            SET v_ret = ROW_COUNT();

            IF v_ret = v_room_cnt AND v_room_cnt > 0 THEN
                COMMIT;
                SET v_msg = 'SUC';
            ELSEIF v_room_cnt = 0 THEN
                ROLLBACK;
                SET v_msg = 'ERR_NO_ROOM';
            ELSE
                ROLLBACK;
                SET v_msg = 'ERR';
            END IF;
        END IF;
    END IF;

    SELECT v_msg AS 'RETURN', v_ret AS updated_rooms;
END$$


-- ============================================================
-- 16) 이벤트 상위 4명 순위 — 결승 스테이지 (통합, review §8)
-- 사용 예제: CALL sp_event_participants_select(1001);
-- ============================================================
DROP PROCEDURE IF EXISTS `sp_event_participants_select`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_event_participants_select`(
    IN p_event_id INT
)
BEGIN
    IF p_event_id IS NULL OR p_event_id <= 0 THEN
        SELECT 'ERR' AS 'RETURN', 'event_id가 유효하지 않습니다.' AS MSG;
    ELSE
        SELECT
            t.participant_id,
            t.entrant_id,
            t.entrant_name,
            t.entrant_image_url,
            t.dummy,
            t.ranking,
            t.winCount,
            t.loseCount
        FROM (
            SELECT
                p.participant_id,
                p.entrant_id,
                p.entrant_name,
                p.entrant_image_url,
                p.dummy,
                b.`order`,
                ROW_NUMBER() OVER (
                    ORDER BY b.`order` ASC, winCount DESC, loseCount ASC, p.participant_id ASC
                ) AS ranking,
                SUM(CASE WHEN bs.winlose = 1 THEN 1 ELSE 0 END) AS winCount,
                SUM(CASE WHEN bs.winlose = 0 THEN 1 ELSE 0 END) AS loseCount
            FROM `brackets` b
            INNER JOIN `bracket_groups` bg ON b.group_id = bg.group_id
            INNER JOIN `bracket_entries` be ON b.bracket_id = be.bracket_id
            INNER JOIN `participants` p ON p.participant_id = be.participant_id
            INNER JOIN `bracket_sets` bs
              ON bs.bracket_id = b.bracket_id AND bs.participant_id = be.participant_id
            WHERE bg.event_id = p_event_id
              AND bg.bracket_type = 'SE'
              AND bg.depth = 2
              AND b.`status` IN (3, 4)
              AND be.`status` > 1
            GROUP BY
                p.participant_id, p.entrant_id, p.entrant_name, p.entrant_image_url,
                p.dummy, b.`order`
        ) t
        ORDER BY t.ranking ASC
        LIMIT 4;
    END IF;
END$$

DELIMITER ;

-- QA 디버그용 SELECT (배포 시 제거 가능)
/*
SELECT
    bg.event_id,
    b.bracket_id,
    bg.depth,
    b.`order`,
    bg.event_id AS bg_event_id,
    bg.depth    AS bg_depth,
    bg.start_dt,
    bg.auto_judge,
    be.participant_id,
    p.entrant_name
FROM brackets b
LEFT JOIN bracket_groups bg ON b.group_id = bg.group_id
LEFT JOIN bracket_entries be ON b.bracket_id = be.bracket_id
LEFT JOIN participants p ON be.participant_id = p.participant_id
WHERE bg.event_id IN (1014, 1033, 1054, 1055)
   OR (bg.group_id IS NULL AND b.group_id NOT IN (
         SELECT group_id FROM bracket_groups WHERE event_id IN (1014, 1033, 1054, 1055)
       ))
ORDER BY COALESCE(bg.event_id, 0), COALESCE(bg.depth, 999999) DESC, b.`order` ASC;
*/