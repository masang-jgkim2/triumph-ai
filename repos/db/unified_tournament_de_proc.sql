USE triumph;
DELIMITER $$

-- ============================================================
-- 파일: unified_tournament_de_proc.sql
-- 통합 토너먼트 저장 프로시저 — DE(Double Elimination) 전용
-- 프로시저명: sp_bracket_de_*
-- ============================================================

-- ============================================================
-- 1) 브라켓 생성
-- DE 전체 브라켓 뼈대 생성 (bracket_groups + brackets + 라우팅)
-- 파라미터: p_event_id, p_participant_count(4/8/16/32/64/128), p_points(BO CSV)
-- 사용 예제: CALL sp_bracket_de_insert(1001, 8, '3,3,3,2,2,2,2,2,2,2,2,2,2,2,3');
-- ============================================================
DROP PROCEDURE IF EXISTS `sp_bracket_de_insert`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_bracket_de_insert`(
    IN p_event_id INT, IN p_participant_count INT, IN p_points VARCHAR(128)
)
BEGIN
    DECLARE v_k INT; DECLARE v_depth INT DEFAULT 1;
    DECLARE v_depth_max INT DEFAULT 0;
    DECLARE v_wb INT DEFAULT 1; DECLARE v_lb INT DEFAULT 1;
    DECLARE v_gid INT;   DECLARE v_gf_gid INT;
    DECLARE v_mcnt INT;  DECLARE v_ord INT;
    DECLARE v_pt INT DEFAULT 1;
    DECLARE v_sp INT DEFAULT 1; DECLARE v_ep INT;
    -- WB/LB group_id 저장용
    DECLARE v_wg1 INT; DECLARE v_wg2 INT; DECLARE v_wg3 INT;
    DECLARE v_wg4 INT; DECLARE v_wg5 INT; DECLARE v_wg6 INT; DECLARE v_wg7 INT;
    DECLARE v_lg1 INT;  DECLARE v_lg2 INT;  DECLARE v_lg3 INT;
    DECLARE v_lg4 INT;  DECLARE v_lg5 INT;  DECLARE v_lg6 INT;
    DECLARE v_lg7 INT;  DECLARE v_lg8 INT;  DECLARE v_lg9 INT;
    DECLARE v_lg10 INT; DECLARE v_lg11 INT; DECLARE v_lg12 INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SELECT 'EXP' AS 'RETURN'; END;

    SET v_k = ROUND(LOG2(p_participant_count));
    IF POW(2, v_k) <> p_participant_count OR v_k < 2 OR v_k > 7 THEN
        SELECT 'ERR' AS 'RETURN', '참가 인원은 4,8,16,32,64,128 중 하나여야 합니다.' AS MSG;
    ELSE

    IF p_points = '' OR p_points IS NULL THEN SET p_points = '3,3,3,2,2,2,2,2,2,2,2,2,2,2,3'; END IF;

    START TRANSACTION;

    -- 기존 데이터 삭제
    DELETE b FROM brackets b INNER JOIN bracket_groups bg ON b.group_id = bg.group_id WHERE bg.event_id = p_event_id;
    DELETE FROM bracket_groups WHERE event_id = p_event_id;

    -- WB 라운드 생성
    SET v_wb = 1;
    WHILE v_wb <= v_k DO
        INSERT INTO bracket_groups (event_id, depth, bracket_type, title, created_dt) VALUES (
            p_event_id, v_depth, 'DE_WB',
            CASE WHEN v_wb = v_k THEN 'WB 결승' WHEN v_wb = v_k-1 THEN 'WB 준결승' ELSE CONCAT('WB R',v_wb) END,
            NOW()
        );
        SET v_gid = LAST_INSERT_ID();
        CASE v_wb WHEN 1 THEN SET v_wg1=v_gid; WHEN 2 THEN SET v_wg2=v_gid; WHEN 3 THEN SET v_wg3=v_gid;
                  WHEN 4 THEN SET v_wg4=v_gid; WHEN 5 THEN SET v_wg5=v_gid; WHEN 6 THEN SET v_wg6=v_gid;
                  WHEN 7 THEN SET v_wg7=v_gid; ELSE BEGIN END; END CASE;
        SET v_wb = v_wb+1; SET v_depth = v_depth+1;
    END WHILE;

    -- LB 라운드 생성
    SET v_lb = 1;
    WHILE v_lb <= 2*(v_k-1) DO
        INSERT INTO bracket_groups (event_id, depth, bracket_type, title, created_dt) VALUES (
            p_event_id, v_depth, 'DE_LB',
            CASE WHEN v_lb = 2*(v_k-1) THEN 'LB 결승' WHEN v_lb = 2*(v_k-1)-1 THEN 'LB 준결승' ELSE CONCAT('LB R',v_lb) END,
            NOW()
        );
        SET v_gid = LAST_INSERT_ID();
        CASE v_lb WHEN 1 THEN SET v_lg1=v_gid;  WHEN 2  THEN SET v_lg2=v_gid;  WHEN 3  THEN SET v_lg3=v_gid;
                  WHEN 4 THEN SET v_lg4=v_gid;  WHEN 5  THEN SET v_lg5=v_gid;  WHEN 6  THEN SET v_lg6=v_gid;
                  WHEN 7 THEN SET v_lg7=v_gid;  WHEN 8  THEN SET v_lg8=v_gid;  WHEN 9  THEN SET v_lg9=v_gid;
                  WHEN 10 THEN SET v_lg10=v_gid; WHEN 11 THEN SET v_lg11=v_gid; WHEN 12 THEN SET v_lg12=v_gid;
                  ELSE BEGIN END; END CASE;
        SET v_lb = v_lb+1; SET v_depth = v_depth+1;
    END WHILE;

    -- GF 생성
    INSERT INTO bracket_groups (event_id, depth, bracket_type, title, created_dt)
    VALUES (p_event_id, v_depth, 'DE_GF', 'Grand Final', NOW());
    SET v_gf_gid = LAST_INSERT_ID();

    -- WB 매치 생성
    SET v_wb = 1;
    WHILE v_wb <= v_k DO
        SET v_ep = LOCATE(',', p_points, v_sp);
        SET v_pt = CAST(IF(v_ep>0, SUBSTRING(p_points,v_sp,v_ep-v_sp), SUBSTRING(p_points,v_sp)) AS UNSIGNED);
        SET v_pt = IF(v_pt=0,1,v_pt);
        SET v_sp = IF(v_ep>0, v_ep+1, v_sp);
        SET v_gid = CASE v_wb
                      WHEN 1 THEN v_wg1 WHEN 2 THEN v_wg2 WHEN 3 THEN v_wg3
                      WHEN 4 THEN v_wg4 WHEN 5 THEN v_wg5 WHEN 6 THEN v_wg6
                      ELSE v_wg7
                    END;
        SET v_mcnt = p_participant_count / POW(2, v_wb); SET v_ord = 1;
        WHILE v_ord <= v_mcnt DO
            INSERT INTO brackets (group_id,`order`,max_capacity,advance_count,match_point,status) VALUES (v_gid,v_ord,2,1,v_pt,0);
            SET v_ord = v_ord+1;
        END WHILE;
        SET v_wb = v_wb+1;
    END WHILE;

    -- LB 매치 생성
    SET v_lb = 1; SET v_mcnt = p_participant_count/4;
    WHILE v_lb <= 2*(v_k-1) DO
        SET v_ep = LOCATE(',', p_points, v_sp);
        SET v_pt = CAST(IF(v_ep>0, SUBSTRING(p_points,v_sp,v_ep-v_sp), SUBSTRING(p_points,v_sp)) AS UNSIGNED);
        SET v_pt = IF(v_pt=0,1,v_pt);
        SET v_sp = IF(v_ep>0, v_ep+1, v_sp);
        SET v_gid = CASE v_lb
                      WHEN 1 THEN v_lg1 WHEN 2 THEN v_lg2 WHEN 3 THEN v_lg3 WHEN 4 THEN v_lg4
                      WHEN 5 THEN v_lg5 WHEN 6 THEN v_lg6 WHEN 7 THEN v_lg7 WHEN 8 THEN v_lg8
                      WHEN 9 THEN v_lg9 WHEN 10 THEN v_lg10 WHEN 11 THEN v_lg11
                      ELSE v_lg12
                    END;
        SET v_ord = 1;
        WHILE v_ord <= v_mcnt DO
            INSERT INTO brackets (group_id,`order`,max_capacity,advance_count,match_point,status) VALUES (v_gid,v_ord,2,1,v_pt,0);
            SET v_ord = v_ord+1;
        END WHILE;
        IF v_lb % 2 = 0 THEN SET v_mcnt = v_mcnt/2; END IF;
        SET v_lb = v_lb+1;
    END WHILE;

    -- GF 매치 생성
    SET v_ep = LOCATE(',', p_points, v_sp);
    SET v_pt = CAST(IF(v_ep>0, SUBSTRING(p_points,v_sp,v_ep-v_sp), SUBSTRING(p_points,v_sp)) AS UNSIGNED);
    SET v_pt = IF(v_pt=0,1,v_pt);
    INSERT INTO brackets (group_id,`order`,max_capacity,advance_count,match_point,status) VALUES (v_gf_gid,1,2,1,v_pt,0);

    -- WB R(i) 승자 → WB R(i+1)
    UPDATE brackets wc INNER JOIN bracket_groups bgc ON wc.group_id=bgc.group_id
    INNER JOIN brackets wn INNER JOIN bracket_groups bgn ON wn.group_id=bgn.group_id
        ON bgn.event_id=bgc.event_id AND bgn.bracket_type='DE_WB'
           AND bgn.depth=bgc.depth+1 AND wn.`order`=CEIL(wc.`order`/2)
    SET wc.next_winner_bracket_id=wn.bracket_id
    WHERE bgc.event_id=p_event_id AND bgc.bracket_type='DE_WB' AND bgc.depth < v_k;

    -- WB Final 승자 → GF
    UPDATE brackets wf INNER JOIN bracket_groups bgf ON wf.group_id=bgf.group_id
    INNER JOIN brackets gf ON gf.group_id=v_gf_gid AND gf.`order`=1
    SET wf.next_winner_bracket_id=gf.bracket_id
    WHERE bgf.event_id=p_event_id AND bgf.bracket_type='DE_WB' AND bgf.depth=v_k;

    -- WB R1 패자 → LB R1
    UPDATE brackets w1 INNER JOIN bracket_groups bg1 ON w1.group_id=bg1.group_id
    INNER JOIN brackets l1 INNER JOIN bracket_groups bgl1 ON l1.group_id=bgl1.group_id
        ON bgl1.event_id=p_event_id AND bgl1.bracket_type='DE_LB'
           AND bgl1.depth=v_k+1 AND l1.`order`=CEIL(w1.`order`/2)
    SET w1.next_loser_bracket_id=l1.bracket_id
    WHERE bg1.event_id=p_event_id AND bg1.bracket_type='DE_WB' AND bg1.depth=1;

    -- WB R2...(Final-1) 패자 → LB Seeded 라운드
    SET v_wb = 2;
    WHILE v_wb <= v_k-1 DO
        SET @lbd = v_k + 2*(v_wb-1);
        UPDATE brackets wr INNER JOIN bracket_groups bgw ON wr.group_id=bgw.group_id
        INNER JOIN brackets ls INNER JOIN bracket_groups bgl ON ls.group_id=bgl.group_id
            ON bgl.event_id=p_event_id AND bgl.bracket_type='DE_LB'
               AND bgl.depth=@lbd AND ls.`order`=wr.`order`
        SET wr.next_loser_bracket_id=ls.bracket_id
        WHERE bgw.event_id=p_event_id AND bgw.bracket_type='DE_WB' AND bgw.depth=v_wb;
        SET v_wb = v_wb+1;
    END WHILE;

    -- WB Final 패자 → LB Final
    SET @lbd_final = v_k + 2*(v_k-1);
    UPDATE brackets wfin INNER JOIN bracket_groups bgwf ON wfin.group_id=bgwf.group_id
    INNER JOIN brackets lfin INNER JOIN bracket_groups bglf ON lfin.group_id=bglf.group_id
        ON bglf.event_id=p_event_id AND bglf.bracket_type='DE_LB'
           AND bglf.depth=@lbd_final AND lfin.`order`=1
    SET wfin.next_loser_bracket_id=lfin.bracket_id
    WHERE bgwf.event_id=p_event_id AND bgwf.bracket_type='DE_WB' AND bgwf.depth=v_k;

    -- LB R(i) 승자 → LB R(i+1)
    -- DE 규칙:
    --  - 홀수 LB 라운드(1,3,5...) -> 다음 짝수 라운드는 1:1 매핑(order 유지)
    --  - 짝수 LB 라운드(2,4,6...) -> 다음 홀수 라운드는 2:1 병합(CEIL(order/2))
    --
    -- LB 라운드 인덱스 = (depth - v_k)
    --   예) v_k=3 일 때 LB depth 4,5,6,7 -> LB round 1,2,3,4

    -- (A) 홀수 라운드 -> 1:1
    UPDATE brackets lc INNER JOIN bracket_groups bglc ON lc.group_id=bglc.group_id
    INNER JOIN brackets ln INNER JOIN bracket_groups bgln ON ln.group_id=bgln.group_id
        ON bgln.event_id=bglc.event_id AND bgln.bracket_type='DE_LB'
           AND bgln.depth=bglc.depth+1 AND ln.`order`=lc.`order`
    SET lc.next_winner_bracket_id=ln.bracket_id
    WHERE bglc.event_id=p_event_id
      AND bglc.bracket_type='DE_LB'
      AND bglc.depth < v_k+2*(v_k-1)
      AND MOD(bglc.depth - v_k, 2) = 1;

    -- (B) 짝수 라운드 -> 2:1 병합
    UPDATE brackets lc INNER JOIN bracket_groups bglc ON lc.group_id=bglc.group_id
    INNER JOIN brackets ln INNER JOIN bracket_groups bgln ON ln.group_id=bgln.group_id
        ON bgln.event_id=bglc.event_id AND bgln.bracket_type='DE_LB'
           AND bgln.depth=bglc.depth+1 AND ln.`order`=CEIL(lc.`order`/2)
    SET lc.next_winner_bracket_id=ln.bracket_id
    WHERE bglc.event_id=p_event_id
      AND bglc.bracket_type='DE_LB'
      AND bglc.depth < v_k+2*(v_k-1)
      AND MOD(bglc.depth - v_k, 2) = 0;

    -- LB Final 승자 → GF
    UPDATE brackets lfin2 INNER JOIN bracket_groups bglf2 ON lfin2.group_id=bglf2.group_id
    INNER JOIN brackets gf2 ON gf2.group_id=v_gf_gid AND gf2.`order`=1
    SET lfin2.next_winner_bracket_id=gf2.bracket_id
    WHERE bglf2.event_id=p_event_id AND bglf2.bracket_type='DE_LB' AND bglf2.depth=v_k+2*(v_k-1);

    -- DE depth 표시 순서 뒤집기 (실험):
    -- 기존: 1 -> 2 -> 3 ... 증가
    -- 변경: 최대 depth 부터 1까지 감소 (예: 8,7,6...1)
    -- 주의: 라우팅은 bracket_id 기반으로 이미 연결 완료된 뒤라 영향 없음
    SET v_depth_max = v_depth;
    -- uq_event_depth(event_id, depth) 충돌 방지:
    -- 1) depth를 큰 영역으로 밀어낸 뒤
    -- 2) 역순 값으로 재배치
    UPDATE bracket_groups
    SET depth = depth + v_depth_max
    WHERE event_id = p_event_id
      AND bracket_type IN ('DE_WB','DE_LB','DE_GF');

    UPDATE bracket_groups
    SET depth = (2 * v_depth_max + 1) - depth
    WHERE event_id = p_event_id
      AND bracket_type IN ('DE_WB','DE_LB','DE_GF');

    COMMIT;

    SELECT bg.bracket_type AS '타입', bg.title AS '라운드', COUNT(b.bracket_id) AS '매치수'
    FROM bracket_groups bg LEFT JOIN brackets b ON b.group_id=bg.group_id
    WHERE bg.event_id=p_event_id GROUP BY bg.group_id ORDER BY bg.depth DESC;

    END IF;
END$$

-- ============================================================
-- 2) 참가자 배치 (체크인 완료 대상)
-- DE WB R1에 참가자 배치
-- 파라미터: p_event_id, p_entries (참가자 ID CSV, 순서대로 2개씩 한 매치)
-- 사용 예제: CALL sp_bracket_de_entries_insert(1001, '101,102,103,104,105,106,107,108');
-- ============================================================
DROP PROCEDURE IF EXISTS `sp_bracket_de_entries_insert`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_bracket_de_entries_insert`(
    IN p_event_id INT, IN p_entries VARCHAR(2048)
)
BEGIN
    DECLARE v_ret INT DEFAULT 0;
    DECLARE v_expected_matches INT DEFAULT 0;
    DECLARE v_tmp_rows INT DEFAULT 0;
    DECLARE v_pos INT DEFAULT 1; DECLARE v_end INT;
    DECLARE v_pid INT; DECLARE v_ord INT DEFAULT 1;
    DECLARE v_bid BIGINT; DECLARE v_wg1_gid INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SELECT 'EXP' AS 'RETURN'; END;

    -- DE depth 역순 저장 기준에서는 WB R1이 최대 depth
    SELECT group_id INTO v_wg1_gid FROM bracket_groups
    WHERE event_id=p_event_id AND bracket_type='DE_WB' ORDER BY depth DESC LIMIT 1;

    IF v_wg1_gid IS NULL THEN
        SELECT 'ERR' AS 'RETURN', 'WB R1 없음. sp_bracket_de_insert 먼저 실행' AS MSG;
    ELSEIF p_entries IS NULL OR TRIM(p_entries) = '' THEN
        SELECT 'ERR' AS 'RETURN', '참가자 CSV(p_entries)가 비어 있습니다.' AS MSG;
    ELSE
        SELECT COUNT(*) INTO v_expected_matches
        FROM brackets
        WHERE group_id = v_wg1_gid;

        CREATE TEMPORARY TABLE IF NOT EXISTS tmp_de_ent (bracket_id BIGINT UNSIGNED, participant_id INT UNSIGNED, slot_index TINYINT);
        TRUNCATE tmp_de_ent;

        parse_entries_loop: WHILE v_pos > 0 DO
            -- slot 0
            SET v_end = LOCATE(',', p_entries, v_pos);
            SET v_pid = CAST(IF(v_end>0, SUBSTRING(p_entries,v_pos,v_end-v_pos), SUBSTRING(p_entries,v_pos)) AS UNSIGNED);
            SET v_pos = IF(v_end>0, v_end+1, 0);
            SELECT bracket_id INTO v_bid FROM brackets WHERE group_id=v_wg1_gid AND `order`=v_ord;
            IF v_bid IS NULL THEN
                LEAVE parse_entries_loop;
            END IF;
            IF v_pid > 0 THEN INSERT INTO tmp_de_ent VALUES (v_bid, v_pid, 0); END IF;
            -- slot 1
            IF v_pos > 0 THEN
                SET v_end = LOCATE(',', p_entries, v_pos);
                SET v_pid = CAST(IF(v_end>0, SUBSTRING(p_entries,v_pos,v_end-v_pos), SUBSTRING(p_entries,v_pos)) AS UNSIGNED);
                SET v_pos = IF(v_end>0, v_end+1, 0);
                IF v_pid > 0 THEN INSERT INTO tmp_de_ent VALUES (v_bid, v_pid, 1); END IF;
            END IF;
            SET v_ord = v_ord+1;
        END WHILE parse_entries_loop;

        SELECT COUNT(*) INTO v_tmp_rows FROM tmp_de_ent;
        IF v_tmp_rows = 0 THEN
            SELECT 'ERR' AS 'RETURN',
                   CONCAT('배치 실패: 유효 참가자 없음. event_id=', p_event_id,
                          ', WB R1 match=', v_expected_matches,
                          ', entries=', IFNULL(p_entries,'NULL')) AS MSG;
            DROP TEMPORARY TABLE IF EXISTS tmp_de_ent;
        ELSE
            START TRANSACTION;
            DELETE be FROM bracket_entries be INNER JOIN brackets b ON be.bracket_id=b.bracket_id WHERE b.group_id=v_wg1_gid;
            INSERT INTO bracket_entries (bracket_id, participant_id, slot_index, status) SELECT bracket_id, participant_id, slot_index, 0 FROM tmp_de_ent;
            SELECT ROW_COUNT() INTO v_ret;
            IF v_ret > 0 THEN
                COMMIT; SELECT 'SUC' AS 'RETURN', CONCAT(v_ret, '명 배치') AS MSG;
            ELSE
                ROLLBACK; SELECT 'ERR' AS 'RETURN', '배치 실패: INSERT 결과 0건' AS MSG;
            END IF;
            DROP TEMPORARY TABLE IF EXISTS tmp_de_ent;
        END IF;
    END IF;
END$$

-- ============================================================
-- 3) 판정 (수동/단건 실행)
-- DE 자동 판정 (WB/LB/GF 공통)
-- next_winner_bracket_id / next_loser_bracket_id 기반 라우팅
-- 파라미터: p_event_id (0이면 전체 처리)
-- 사용 예제: CALL sp_bracket_de_adjudge(1001);
-- ============================================================
DROP PROCEDURE IF EXISTS `sp_bracket_de_adjudge`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_bracket_de_adjudge`(
    IN p_event_id INT
)
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_processed INT DEFAULT 0;
    DECLARE v_bid BIGINT; DECLARE v_event_id INT; DECLARE v_btype VARCHAR(10);
    DECLARE v_bord INT;
    DECLARE v_nwid BIGINT; DECLARE v_nlid BIGINT;
    DECLARE v_has_cleanup_table INT DEFAULT 0;
    DECLARE v_has_scheduled_close_dt INT DEFAULT 0;
    DECLARE v_has_cleanup_status INT DEFAULT 0;
    DECLARE v_has_cleanup_created_at INT DEFAULT 0;
    DECLARE v_has_cleanup_updated_at INT DEFAULT 0;

    DECLARE cur CURSOR FOR
        SELECT b.bracket_id, bg.event_id, bg.bracket_type,
               b.`order`,
               b.next_winner_bracket_id, b.next_loser_bracket_id
        FROM brackets b
        INNER JOIN bracket_groups bg ON b.group_id = bg.group_id
        WHERE b.status = 2
          AND bg.bracket_type IN ('DE_WB','DE_LB','DE_GF')
          AND (p_event_id = 0 OR p_event_id IS NULL OR bg.event_id = p_event_id)
          -- 양측 참가자 세트 제출 완료 확인
          AND (SELECT COUNT(DISTINCT be.participant_id) FROM bracket_entries be
               LEFT JOIN bracket_sets bs ON be.bracket_id=bs.bracket_id AND be.participant_id=bs.participant_id
               WHERE be.bracket_id=b.bracket_id AND be.status=2 AND bs.bracket_id IS NOT NULL) = 2
          -- winlose 합계 = match_point 검증
          AND (SELECT SUM(bs2.winlose) FROM bracket_sets bs2
               INNER JOIN bracket_entries be2 ON bs2.bracket_id=be2.bracket_id AND bs2.participant_id=be2.participant_id
               WHERE bs2.bracket_id=b.bracket_id AND be2.status=2) = b.match_point
          -- 세트별 winlose 상호 배타성 (합=1)
          AND NOT EXISTS (
              SELECT 1 FROM bracket_sets bsx
              INNER JOIN bracket_entries bex ON bsx.bracket_id=bex.bracket_id AND bsx.participant_id=bex.participant_id
              WHERE bsx.bracket_id=b.bracket_id AND bex.status=2
              GROUP BY bsx.set_order HAVING SUM(bsx.winlose) <> 1
          );

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    -- 판정 진행 로그 (호출자가 매 루프 진행 상황 확인 가능)
    DROP TEMPORARY TABLE IF EXISTS tmp_de_adjudge_log;
    CREATE TEMPORARY TABLE tmp_de_adjudge_log (
        seq_no INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        event_id INT NOT NULL,
        bracket_id BIGINT UNSIGNED NOT NULL,
        bracket_type VARCHAR(10) NOT NULL,
        winner_participant_id INT NULL,
        loser_participant_id INT NULL,
        next_winner_bracket_id BIGINT UNSIGNED NULL,
        next_loser_bracket_id BIGINT UNSIGNED NULL,
        result_msg VARCHAR(255) NOT NULL,
        processed_at DATETIME NOT NULL
    );

    OPEN cur;

    read_loop: LOOP
        FETCH cur INTO v_bid, v_event_id, v_btype, v_bord, v_nwid, v_nlid;
        IF done THEN LEAVE read_loop; END IF;

        BEGIN
            DECLARE v_p1 INT; DECLARE v_p2 INT;
            DECLARE v_s1 INT; DECLARE v_s2 INT;
            DECLARE v_d1 TINYINT; DECLARE v_d2 TINYINT;
            DECLARE v_winner INT; DECLARE v_loser INT;
            DECLARE v_win_slot TINYINT; DECLARE v_los_slot TINYINT;
            DECLARE v_nw_slot TINYINT; DECLARE v_nl_slot TINYINT;

            -- 두 참가자 점수 조회
            SELECT be1.participant_id,
                   IFNULL((SELECT SUM(winlose) FROM bracket_sets WHERE bracket_id=be1.bracket_id AND participant_id=be1.participant_id),0),
                   p1.dummy,
                   be2.participant_id,
                   IFNULL((SELECT SUM(winlose) FROM bracket_sets WHERE bracket_id=be2.bracket_id AND participant_id=be2.participant_id),0),
                   p2.dummy
            INTO v_p1, v_s1, v_d1, v_p2, v_s2, v_d2
            FROM bracket_entries be1
            JOIN participants p1 ON be1.participant_id=p1.participant_id
            JOIN bracket_entries be2 ON be1.bracket_id=be2.bracket_id AND be1.participant_id < be2.participant_id
            JOIN participants p2 ON be2.participant_id=p2.participant_id
            WHERE be1.bracket_id=v_bid AND be1.status=2 AND be2.status=2 LIMIT 1;

            -- 승패 결정
            IF v_s1 > v_s2 THEN SET v_winner=v_p1; SET v_loser=v_p2;
            ELSEIF v_s2 > v_s1 THEN SET v_winner=v_p2; SET v_loser=v_p1;
            ELSEIF v_d1=0 AND v_d2=1 THEN SET v_winner=v_p1; SET v_loser=v_p2;
            ELSEIF v_d1=1 AND v_d2=0 THEN SET v_winner=v_p2; SET v_loser=v_p1;
            ELSE
                IF RAND() < 0.5 THEN SET v_winner=v_p1; SET v_loser=v_p2;
                ELSE SET v_winner=v_p2; SET v_loser=v_p1; END IF;
            END IF;

            -- 슬롯 인덱스 확인 (다음 매치 배치용)
            SELECT slot_index INTO v_win_slot FROM bracket_entries WHERE bracket_id=v_bid AND participant_id=v_winner LIMIT 1;
            SET v_los_slot = 1 - v_win_slot;

            START TRANSACTION;

            -- 현재 매치 업데이트
            UPDATE brackets SET winner_entrant_id=v_winner, status=3, match_end_dt=NOW()
            WHERE bracket_id=v_bid;

            -- bracket_sets(winlose) 누적을 bracket_entries.score에 반영
            UPDATE bracket_entries be
            SET be.score = (
                SELECT IFNULL(SUM(bs.winlose), 0)
                FROM bracket_sets bs
                WHERE bs.bracket_id = be.bracket_id
                  AND bs.participant_id = be.participant_id
            )
            WHERE be.bracket_id = v_bid
              AND be.status = 2;

            UPDATE bracket_entries SET status=4, is_advanced=1
            WHERE bracket_id=v_bid AND participant_id=v_winner;

            -- LB 패자는 is_advanced=1 유지, WB/GF 패자는 탈락
            UPDATE bracket_entries
            SET status=5,
                is_advanced = CASE WHEN v_btype='DE_WB' AND v_nlid IS NOT NULL THEN 1 ELSE 0 END
            WHERE bracket_id=v_bid AND participant_id=v_loser;

            -- 승자 → 다음 매치 배정
            IF v_nwid IS NOT NULL THEN
                -- 다음 매치 슬롯 배정 규칙
                -- 1) 반대 슬롯이 비어있으면 그 슬롯 사용
                -- 2) 둘 다 비어있으면 현재 경기 order(홀/짝)로 결정(홀수=0, 짝수=1)
                SET v_nw_slot = CASE
                    WHEN EXISTS (
                        SELECT 1 FROM bracket_entries
                        WHERE bracket_id = v_nwid AND slot_index = 0 AND participant_id <> v_winner
                    ) AND NOT EXISTS (
                        SELECT 1 FROM bracket_entries
                        WHERE bracket_id = v_nwid AND slot_index = 1 AND participant_id <> v_winner
                    ) THEN 1
                    WHEN EXISTS (
                        SELECT 1 FROM bracket_entries
                        WHERE bracket_id = v_nwid AND slot_index = 1 AND participant_id <> v_winner
                    ) AND NOT EXISTS (
                        SELECT 1 FROM bracket_entries
                        WHERE bracket_id = v_nwid AND slot_index = 0 AND participant_id <> v_winner
                    ) THEN 0
                    ELSE CASE WHEN MOD(v_bord, 2) = 1 THEN 0 ELSE 1 END
                END;

                INSERT INTO bracket_entries (bracket_id, participant_id, slot_index, status)
                VALUES (v_nwid, v_winner, v_nw_slot, 0)
                ON DUPLICATE KEY UPDATE status = VALUES(status), slot_index = VALUES(slot_index);
            END IF;

            -- 패자 → LB 배정 (DE_WB 한정)
            IF v_nlid IS NOT NULL AND v_btype = 'DE_WB' THEN
                SET v_nl_slot = CASE
                    WHEN EXISTS (
                        SELECT 1 FROM bracket_entries
                        WHERE bracket_id = v_nlid AND slot_index = 0 AND participant_id <> v_loser
                    ) AND NOT EXISTS (
                        SELECT 1 FROM bracket_entries
                        WHERE bracket_id = v_nlid AND slot_index = 1 AND participant_id <> v_loser
                    ) THEN 1
                    WHEN EXISTS (
                        SELECT 1 FROM bracket_entries
                        WHERE bracket_id = v_nlid AND slot_index = 1 AND participant_id <> v_loser
                    ) AND NOT EXISTS (
                        SELECT 1 FROM bracket_entries
                        WHERE bracket_id = v_nlid AND slot_index = 0 AND participant_id <> v_loser
                    ) THEN 0
                    ELSE CASE WHEN MOD(v_bord, 2) = 1 THEN 0 ELSE 1 END
                END;

                INSERT INTO bracket_entries (bracket_id, participant_id, slot_index, status)
                VALUES (v_nlid, v_loser, v_nl_slot, 0)
                ON DUPLICATE KEY UPDATE status = VALUES(status), slot_index = VALUES(slot_index);
            END IF;

            -- GF 완료 → 대회 종료 예약 + 1,2위 확정
            IF v_btype = 'DE_GF' THEN
                -- 레거시/혼합 DB 호환:
                -- event_cleanup_auto 테이블은 있으나 scheduled_close_dt 컬럼이 없는 경우가 있어
                -- 최초 실행 시 자동 보정 후 종료 예약을 기록한다.
                SELECT COUNT(*)
                  INTO v_has_cleanup_table
                FROM information_schema.tables
                WHERE table_schema = DATABASE()
                  AND table_name = 'event_cleanup_auto';

                IF v_has_cleanup_table = 0 THEN
                    CREATE TABLE IF NOT EXISTS event_cleanup_auto (
                        event_id INT NOT NULL,
                        scheduled_close_dt DATETIME NULL,
                        status TINYINT NOT NULL DEFAULT 0,
                        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                        PRIMARY KEY (event_id)
                    );
                ELSE
                    SELECT COUNT(*)
                      INTO v_has_scheduled_close_dt
                    FROM information_schema.columns
                    WHERE table_schema = DATABASE()
                      AND table_name = 'event_cleanup_auto'
                      AND column_name = 'scheduled_close_dt';

                    IF v_has_scheduled_close_dt = 0 THEN
                        ALTER TABLE event_cleanup_auto
                            ADD COLUMN scheduled_close_dt DATETIME NULL AFTER event_id;
                    END IF;

                    SELECT COUNT(*)
                      INTO v_has_cleanup_status
                    FROM information_schema.columns
                    WHERE table_schema = DATABASE()
                      AND table_name = 'event_cleanup_auto'
                      AND column_name = 'status';

                    IF v_has_cleanup_status = 0 THEN
                        ALTER TABLE event_cleanup_auto
                            ADD COLUMN status TINYINT NOT NULL DEFAULT 0 AFTER scheduled_close_dt;
                    END IF;

                    SELECT COUNT(*)
                      INTO v_has_cleanup_created_at
                    FROM information_schema.columns
                    WHERE table_schema = DATABASE()
                      AND table_name = 'event_cleanup_auto'
                      AND column_name = 'created_at';

                    IF v_has_cleanup_created_at = 0 THEN
                        ALTER TABLE event_cleanup_auto
                            ADD COLUMN created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP AFTER status;
                    END IF;

                    SELECT COUNT(*)
                      INTO v_has_cleanup_updated_at
                    FROM information_schema.columns
                    WHERE table_schema = DATABASE()
                      AND table_name = 'event_cleanup_auto'
                      AND column_name = 'updated_at';

                    IF v_has_cleanup_updated_at = 0 THEN
                        ALTER TABLE event_cleanup_auto
                            ADD COLUMN updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
                            ON UPDATE CURRENT_TIMESTAMP
                            AFTER created_at;
                    END IF;
                END IF;

                INSERT INTO event_cleanup_auto (event_id, scheduled_close_dt, status, created_at, updated_at)
                VALUES (v_event_id, NOW() + INTERVAL 24 HOUR, 0, NOW(), NOW())
                ON DUPLICATE KEY UPDATE
                    scheduled_close_dt = IF(status=0, NOW()+INTERVAL 24 HOUR, scheduled_close_dt),
                    updated_at = NOW();

                UPDATE participants SET final_rank=1 WHERE participant_id=v_winner AND event_id=v_event_id;
                UPDATE participants SET final_rank=2 WHERE participant_id=v_loser  AND event_id=v_event_id;
            END IF;

            INSERT INTO tmp_de_adjudge_log (
                event_id, bracket_id, bracket_type,
                winner_participant_id, loser_participant_id,
                next_winner_bracket_id, next_loser_bracket_id,
                result_msg, processed_at
            ) VALUES (
                v_event_id, v_bid, v_btype,
                v_winner, v_loser,
                v_nwid, v_nlid,
                CASE WHEN v_btype='DE_GF' THEN 'GF 판정 완료 (1/2위 반영)'
                     ELSE '브라켓 판정 완료'
                END,
                NOW()
            );

            COMMIT;
            SET v_processed = v_processed + 1;
        END;
    END LOOP;
    CLOSE cur;

    -- 1) 판정 상세 로그
    SELECT
        seq_no,
        event_id,
        bracket_id,
        bracket_type,
        winner_participant_id,
        loser_participant_id,
        next_winner_bracket_id,
        next_loser_bracket_id,
        result_msg,
        processed_at
    FROM tmp_de_adjudge_log
    ORDER BY seq_no;

    -- 2) 요약
    SELECT 'DONE' AS 'RETURN', v_processed AS processed_brackets;
END$$

-- ============================================================
-- 4) 랜덤 경기 진행 데이터 생성 (테스트/시뮬레이션용)
-- event_id 기준으로 아직 미진행 브라켓을 랜덤 선택해 세트 결과를 생성하고
-- bracket_entries/brackets 상태를 판정대기(status=2)로 올림
-- 파라미터: p_event_id, p_target_count(생성할 매치 수, NULL/<1이면 1건)
-- 사용 예제: CALL sp_bracket_de_score_auto(1001, 1);
-- ============================================================
DROP PROCEDURE IF EXISTS `sp_bracket_de_score_auto`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_bracket_de_score_auto`(
    IN p_event_id INT,
    IN p_target_count INT
)
BEGIN
    DECLARE v_bid BIGINT;
    DECLARE v_match_point INT;
    DECLARE v_winner_pid INT;
    DECLARE v_done_count INT DEFAULT 0;
    DECLARE v_loop_limit INT DEFAULT 0;

    IF p_target_count IS NULL OR p_target_count < 1 THEN
        SET v_loop_limit = 1;
    ELSE
        SET v_loop_limit = p_target_count;
    END IF;

    score_loop: WHILE v_done_count < v_loop_limit DO
        SET v_bid = NULL;
        SET v_match_point = NULL;

        SELECT b.bracket_id, b.match_point
          INTO v_bid, v_match_point
        FROM brackets b
        INNER JOIN bracket_groups bg ON bg.group_id = b.group_id
        WHERE bg.event_id = p_event_id
          AND bg.bracket_type IN ('DE_WB','DE_LB','DE_GF')
          AND (
              -- 정상 대기 경기: 아직 세트가 없는 status 0/1
              (
                  b.status IN (0,1)
                  AND (
                      SELECT COUNT(*) FROM bracket_entries be
                      WHERE be.bracket_id = b.bracket_id
                  ) >= 2
                  AND NOT EXISTS (
                      SELECT 1 FROM bracket_sets bs WHERE bs.bracket_id = b.bracket_id
                  )
              )
              OR
              -- 비정상 대기 경기 자동 복구:
              -- status=2인데 세트/승패 합/세트 무결성이 판정 조건을 못 만족하면
              -- score_auto가 다시 세트를 생성해 교착을 해소한다.
              (
                  b.status = 2
                  AND (
                      -- 판정대기 참가자 2명 미만
                      (
                          SELECT COUNT(*) FROM bracket_entries be2
                          WHERE be2.bracket_id = b.bracket_id AND be2.status = 2
                      ) < 2
                      OR
                      -- 승패 합계 불일치
                      (
                          SELECT IFNULL(SUM(bs2.winlose), 0)
                          FROM bracket_sets bs2
                          INNER JOIN bracket_entries be3
                                  ON be3.bracket_id = bs2.bracket_id
                                 AND be3.participant_id = bs2.participant_id
                          WHERE bs2.bracket_id = b.bracket_id
                            AND be3.status = 2
                      ) <> b.match_point
                      OR
                      -- 세트별 winlose 합이 1이 아닌 무결성 오류
                      EXISTS (
                          SELECT 1
                          FROM bracket_sets bsx
                          INNER JOIN bracket_entries bex
                                  ON bex.bracket_id = bsx.bracket_id
                                 AND bex.participant_id = bsx.participant_id
                          WHERE bsx.bracket_id = b.bracket_id
                            AND bex.status = 2
                          GROUP BY bsx.set_order
                          HAVING SUM(bsx.winlose) <> 1
                      )
                  )
              )
          )
        ORDER BY RAND()
        LIMIT 1;

        IF v_bid IS NULL THEN
            LEAVE score_loop;
        END IF;

        -- 랜덤 승자 선택 (2인 매치 전제)
        SELECT be.participant_id
          INTO v_winner_pid
        FROM bracket_entries be
        WHERE be.bracket_id = v_bid
        ORDER BY RAND()
        LIMIT 1;

        -- 안전하게 기존 세트 삭제 후 생성
        DELETE FROM bracket_sets WHERE bracket_id = v_bid;

        INSERT INTO bracket_sets (bracket_id, participant_id, set_order, score, winlose)
        SELECT be.bracket_id,
               be.participant_id,
               seq.n AS set_order,
               0 AS score,
               CASE
                   WHEN be.participant_id = v_winner_pid AND seq.n <= v_match_point THEN 1
                   ELSE 0
               END AS winlose
        FROM bracket_entries be
        INNER JOIN (
            SELECT 1 AS n UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5
            UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9 UNION SELECT 10
        ) seq ON seq.n <= v_match_point
        WHERE be.bracket_id = v_bid;

        UPDATE bracket_entries
        SET status = 2
        WHERE bracket_id = v_bid;

        UPDATE brackets
        SET status = 2
        WHERE bracket_id = v_bid;

        SET v_done_count = v_done_count + 1;
    END WHILE;

    SELECT 'DONE' AS 'RETURN', v_done_count AS generated_matches;
END$$

-- ============================================================
-- 5) 자동 판정 (스케줄러용)
-- auto_judge=1 인 DE 그룹만 대상으로 판정 루프 실행
-- 파라미터: p_event_id (0/NULL이면 auto_judge=1 DE 전체 이벤트)
-- 사용 예제: CALL sp_bracket_de_adjudge_auto(1001);
-- ============================================================
DROP PROCEDURE IF EXISTS `sp_bracket_de_adjudge_auto`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_bracket_de_adjudge_auto`(
    IN p_event_id INT
)
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_event_id INT;
    DECLARE v_cnt INT DEFAULT 0;

    DECLARE cur CURSOR FOR
        SELECT DISTINCT bg.event_id
        FROM bracket_groups bg
        INNER JOIN events e ON e.event_id = bg.event_id
        WHERE bg.bracket_type IN ('DE_WB','DE_LB','DE_GF')
          AND bg.auto_judge = 1
          AND (bg.start_dt IS NULL OR bg.start_dt <= NOW())
          AND e.status = 2
          AND (p_event_id IS NULL OR p_event_id = 0 OR bg.event_id = p_event_id);

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    OPEN cur;
    read_loop: LOOP
        FETCH cur INTO v_event_id;
        IF done THEN LEAVE read_loop; END IF;
        CALL sp_bracket_de_adjudge(v_event_id);
        SET v_cnt = v_cnt + 1;
    END LOOP;
    CLOSE cur;

    SELECT 'DONE' AS 'RETURN', v_cnt AS checked_events;
END$$

-- ============================================================
-- 6) 브라켓 초기화 (하위 라운드 미확정 조건)
-- 조건:
--  - 현재 브라켓의 다음 매치(next_winner / next_loser)가 확정/진행/완료되지 않아야 함
--  - 다음 매치로 넘어간 현재 참가자 엔트리만 제거
--  - 현재 브라켓 점수/상태를 대기로 롤백
-- 파라미터: p_bracket_id (초기화 대상 brackets.bracket_id)
-- 사용 예제: CALL sp_bracket_de_reset(50001);
-- ============================================================
DROP PROCEDURE IF EXISTS `sp_bracket_de_reset`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_bracket_de_reset`(
    IN p_bracket_id BIGINT
)
BEGIN
    DECLARE v_event_id INT;
    DECLARE v_type VARCHAR(10);
    DECLARE v_nwid BIGINT;
    DECLARE v_nlid BIGINT;
    DECLARE v_block INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'EXP' AS 'RETURN', 'reset failed' AS MSG;
    END;

    SELECT bg.event_id, bg.bracket_type, b.next_winner_bracket_id, b.next_loser_bracket_id
      INTO v_event_id, v_type, v_nwid, v_nlid
    FROM brackets b
    INNER JOIN bracket_groups bg ON bg.group_id = b.group_id
    WHERE b.bracket_id = p_bracket_id
      AND bg.bracket_type IN ('DE_WB','DE_LB','DE_GF')
    LIMIT 1;

    IF v_event_id IS NULL THEN
        SELECT 'ERR' AS 'RETURN', '대상 DE 브라켓이 없습니다.' AS MSG;
    ELSE
        -- 다음 승자 브라켓이 이미 진행/완료되었으면 초기화 불가
        IF v_nwid IS NOT NULL THEN
            SELECT COUNT(*) INTO v_block
            FROM brackets b
            LEFT JOIN bracket_entries be ON be.bracket_id = b.bracket_id
            WHERE b.bracket_id = v_nwid
              AND (b.status IN (2,3) OR IFNULL(b.winner_entrant_id,0) <> 0 OR IFNULL(be.status,0) >= 2);
        END IF;

        -- 다음 패자 브라켓이 이미 진행/완료되었으면 초기화 불가
        IF v_block = 0 AND v_nlid IS NOT NULL THEN
            SELECT COUNT(*) INTO v_block
            FROM brackets b
            LEFT JOIN bracket_entries be ON be.bracket_id = b.bracket_id
            WHERE b.bracket_id = v_nlid
              AND (b.status IN (2,3) OR IFNULL(b.winner_entrant_id,0) <> 0 OR IFNULL(be.status,0) >= 2);
        END IF;

        IF v_block > 0 THEN
            SELECT 'ERR' AS 'RETURN', '다음 브라켓이 이미 확정/진행되어 초기화할 수 없습니다.' AS MSG;
        ELSE
            START TRANSACTION;

            -- 현재 브라켓 참가자를 임시 보관
            CREATE TEMPORARY TABLE IF NOT EXISTS tmp_reset_pids (
                participant_id INT UNSIGNED PRIMARY KEY
            );
            TRUNCATE tmp_reset_pids;
            INSERT INTO tmp_reset_pids (participant_id)
            SELECT participant_id FROM bracket_entries WHERE bracket_id = p_bracket_id;

            -- 다음 브라켓에 자동 진출된 엔트리 제거 (현재 브라켓 참가자 대상)
            IF v_nwid IS NOT NULL THEN
                DELETE be
                FROM bracket_entries be
                INNER JOIN tmp_reset_pids t ON t.participant_id = be.participant_id
                WHERE be.bracket_id = v_nwid
                  AND be.status IN (0,1);
            END IF;

            IF v_nlid IS NOT NULL THEN
                DELETE be
                FROM bracket_entries be
                INNER JOIN tmp_reset_pids t ON t.participant_id = be.participant_id
                WHERE be.bracket_id = v_nlid
                  AND be.status IN (0,1);
            END IF;

            -- 현재 브라켓 세트/엔트리 상태 초기화
            DELETE FROM bracket_sets WHERE bracket_id = p_bracket_id;

            UPDATE bracket_entries
            SET status = 0,
                score = 0,
                is_advanced = 0,
                rank_in_match = NULL
            WHERE bracket_id = p_bracket_id;

            UPDATE brackets
            SET status = 0,
                winner_entrant_id = 0,
                match_end_dt = NULL
            WHERE bracket_id = p_bracket_id;

            DROP TEMPORARY TABLE IF EXISTS tmp_reset_pids;
            COMMIT;
            SELECT 'SUC' AS 'RETURN', '브라켓 초기화 완료' AS MSG;
        END IF;
    END IF;
END$$

-- ============================================================
-- 7) DE 참가자 추가
-- participants + participant_members 동시 생성
-- 개인전 기준 기본값:
--   participant_type = 0 (개인)
--   participant_members.role = 'LEADER'
-- 파라미터: p_event_id, p_member_id, p_member_name, p_member_image_url, p_entrant_name, p_entrant_image_url, p_participant_type, p_create_member_id
-- 사용 예제: CALL sp_bracket_de_participant_insert(1001, 900001, 'TEST_MEMBER', NULL, 'TEST_ENTRANT', NULL, 0, 250);
-- ============================================================
DROP PROCEDURE IF EXISTS `sp_bracket_de_participant_insert`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_bracket_de_participant_insert`(
    IN p_event_id INT,
    IN p_member_id INT,
    IN p_member_name VARCHAR(255),
    IN p_member_image_url VARCHAR(512),
    IN p_entrant_name VARCHAR(255),
    IN p_entrant_image_url VARCHAR(512),
    IN p_participant_type TINYINT,
    IN p_create_member_id INT
)
BEGIN
    DECLARE v_participant_id INT UNSIGNED;
    DECLARE v_exists INT DEFAULT 0;
    DECLARE v_entrant_name VARCHAR(255);
    DECLARE v_participant_type TINYINT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'EXP' AS 'RETURN', '참가자 생성 중 예외 발생' AS MSG;
    END;

    -- 필수값 검증
    IF p_event_id IS NULL OR p_event_id <= 0 THEN
        SELECT 'ERR' AS 'RETURN', 'event_id가 유효하지 않습니다.' AS MSG;
    ELSEIF p_member_name IS NULL OR TRIM(p_member_name) = '' THEN
        SELECT 'ERR' AS 'RETURN', 'member_name은 필수입니다.' AS MSG;
    ELSE
        SET v_participant_type = IFNULL(p_participant_type, 0);
        SET v_entrant_name = IFNULL(NULLIF(TRIM(p_entrant_name), ''), p_member_name);

        -- 동일 이벤트에 같은 member_id가 이미 참가자인지 확인 (member_id가 있을 때만)
        IF p_member_id IS NOT NULL AND p_member_id > 0 THEN
            SELECT COUNT(*)
              INTO v_exists
            FROM participants p
            INNER JOIN participant_members pm ON pm.participant_id = p.participant_id
            WHERE p.event_id = p_event_id
              AND pm.member_id = p_member_id;
        END IF;

        IF v_exists > 0 THEN
            SELECT 'DUP' AS 'RETURN', '이미 참가한 멤버입니다.' AS MSG;
        ELSE
            START TRANSACTION;

            -- participants: create_dt·update_dt 명명 유지
            INSERT INTO participants (
                event_id,
                participant_type,
                entrant_id,
                entrant_name,
                entrant_image_url,
                checkin_status,
                checkin_dt,
                final_rank,
                dummy,
                create_member_id,
                create_dt,
                update_dt
            )
            VALUES (
                p_event_id,
                v_participant_type,
                p_member_id,
                v_entrant_name,
                p_entrant_image_url,
                0,
                NULL,
                NULL,
                0,
                IFNULL(p_create_member_id, 0),
                NOW(),
                NULL
            );

            SET v_participant_id = LAST_INSERT_ID();

            INSERT INTO participant_members (
                participant_id,
                member_id,
                member_name,
                member_image_url,
                role,
                dummy,
                create_member_id,
                create_dt,
                update_dt
            )
            VALUES (
                v_participant_id,
                p_member_id,
                p_member_name,
                p_member_image_url,
                'LEADER',
                0,
                IFNULL(p_create_member_id, 0),
                NOW(),
                NULL
            );

            COMMIT;

            SELECT 'SUC' AS 'RETURN', '참가자 생성 완료' AS MSG, v_participant_id AS participant_id;
        END IF;
    END IF;
END$$

DELIMITER ;


