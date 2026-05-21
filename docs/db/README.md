# Triumph DB 문서 (인덱스)

**단일 진실(SQL·스키마 파일):** [`repos/db/README.md`](../../repos/db/README.md)

| 파일 (repos/db) | 용도 |
|-----------------|------|
| `triumph_schema_qa_20260521.sql` | QA 스키마 스냅샷 |
| `unified_tournament_table_migration.sql` | 통합 DDL 마이그레이션 |
| `unified_tournament_se_proc.sql` | SE SP |
| `unified_tournament_de_proc.sql` | DE SP (E3) |

**배포 절차·CI 한계:** [db-deployment.md](../db-deployment.md)  
**에픽:** [HANDOFF.md](../HANDOFF.md) — E3 더블 엘리미네이션

**에이전트:** `@be-dev` (구현·SP), `@planning-architecture` (계약·Handoff), 배포 깃 (QA→Live)
