# Triumph DB 참고 자료 (`repos/db`)

> **용도:** QA 스키마 스냅샷, 통합 토너먼트(SE/DE) DDL·SP.  
> **대상:** `@be-dev`, `@planning-architecture`, 배포 깃, E3 더블 엘리미네이션.  
> **주의:** 운영·QA DB에 적용 전 반드시 백업. `triumph` DB 기준.

이 폴더는 **서비스 repo 클론이 아닙니다** (`repos/global-*` 와 별도).

---

## 파일 목록

| 파일 | 내용 | 적용 순서 |
|------|------|-----------|
| `triumph_schema_qa_20260521.sql` | QA DB **현재 구조** 덤프 (테이블·일부 SP) | 참고·diff 기준 |
| `unified_tournament_table_migration.sql` | 레거시 SE → **통합 스키마** ALTER | **1** (DDL) |
| `unified_tournament_se_proc.sql` | 통합 스키마 **SE** SP (`sp_bracket_single_insert` 등) | **2a** |
| `unified_tournament_de_proc.sql` | 통합 스키마 **DE** SP (`sp_bracket_de_*`) | **2b** (E3) |

### QA 스냅샷에 이미 보이는 통합 키워드

- `bracket_groups.bracket_type`: `SE`, `DE_WB`, `DE_LB`, `DE_GF`, `FFA`
- `brackets.next_winner_bracket_id`, `next_loser_bracket_id` (DE 라우팅)
- `events.format`: `0` 싱글, `1` 더블, `2` 풀 리그 (앱 레이어)

### DE SP (예시, `unified_tournament_de_proc.sql`)

- `sp_bracket_de_insert` — DE 뼈대 생성
- 그 외 판정·엔트리·승자 갱신 등 파일 내 주석·목차 참고

### SE SP (예시, `unified_tournament_se_proc.sql`)

- `sp_bracket_single_insert` — 통합 `bracket_groups` + `group_id` 구조용 SE 생성
- `sp_bracket_adjudge_*`, `sp_bracket_winner_update` 등

---

## 권장 적용 순서 (QA)

```text
1. triumph_schema_qa_*.sql 로 현재 상태 확인 (또는 백업)
2. unified_tournament_table_migration.sql  (UTF-8로 mysql 실행)
3. unified_tournament_se_proc.sql           (싱글 회귀·기존 이벤트)
4. unified_tournament_de_proc.sql           (format=1 / E3)
5. API(BracketsRepository) · WS · FE 연동 검증
```

**인코딩:** Windows에서 한글 주석 깨짐 시 migration 파일 상단 주석대로 `UTF-8`로 파이프.

**검증:** migration 파일 하단 `V6`~`V7` 등 검증 쿼리 실행.  
(별도 `unified_tournament_table_migration_verify.sql` 있으면 DDL 전·후 비교)

---

## 코드 repo와의 관계

| 레이어 | repo | 비고 |
|--------|------|------|
| SP 호출 | `repos/global-apiserver` | 현재 코드는 레거시 `sp_bracket_single_insert` 등 — 통합 SP로 **교체·분기** 필요 |
| Prisma | `repos/global-renewal-websocket` | DDL 반영 후 `prisma db pull` → `generate` |
| FE | `repos/global-triumphserver` | `format=1`, WB/LB UI — E3 Handoff |

상세 배포: [docs/db-deployment.md](../../docs/db-deployment.md)  
E3 에픽: [docs/HANDOFF.md](../../docs/HANDOFF.md) §7

---

## Git

`triumph_ai` 루트 `.gitignore`에서 **`repos/db/`만 예외**로 커밋 가능.  
스키마 덤프·SQL은 팀 공유용(비밀번호·데이터 없음 DDL/SP 위주).
