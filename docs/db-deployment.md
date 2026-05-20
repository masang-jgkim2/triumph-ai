# Triumph — DB 배포 정리

> **Cursor 세션:** `배포 깃`  
> Git push만으로 DB 스키마가 올라가지 않음. QA DB → 검증 → Live DB(백업) → 백엔드/프론트 배포 순서를 따른다.  
> 상황별 전체 플레이북: [deployment-playbook.md](./deployment-playbook.md)

---

## 1. 한눈에

| 서비스 | DB 연결 | 스키마 관리 | CI에서 DB 적용 |
|--------|---------|-------------|----------------|
| **프론트** (`global-triumphserver`) | 없음 | — | 해당 없음 |
| **API** (`global-apiserver`) | `.env` `DB_HOST`, `DB_*` | `database/migrations/` | **없음** (팀·서버에서 `migrate` 여부 확인) |
| **WebSocket** (`global-renewal-websocket`) | `.env` `DATABASE_URL` | `prisma/schema.prisma` | **`prisma generate`만** (`migrate deploy` 없음) |
| **triumph_ai** | 없음 | — | 운영 배포 없음 |

**env 위치 (DB IP는 triumph_ai `env`에 없음)**

| 환경 | 파일 |
|------|------|
| 프론트 QA/Live URL | `triumph_ai\env`, `env.qa`, `env.production` → `sync-env.ps1` |
| API DB | `repos/global-apiserver/.env` (팀 제공) |
| WS DB | `repos/global-renewal-websocket/.env` (팀 제공) |
| WS 서버 배포 시 | `/home/ubuntu/env/.env` (CodeDeploy `after_install.sh`) |

---

## 2. CI·배포 스크립트가 하는 일

### API (`global-apiserver`)

- GitLab: `qa` push → SSH `git_deploy_qa.sh` (Live는 팀 파이프라인 추가 확인)
- repo 안에 `php artisan migrate` 호출 **없음**
- `database/migrations/`에는 Laravel 기본 4개만 존재 → **게임 본 DB는 별도 관리(SP/SQL)** 가능성 큼

### WebSocket (`global-renewal-websocket`)

- `qa` 브랜치: **빌드 검증만**, 배포 없음
- `release/*`, `hotfix/*` → S3 → QA CodeDeploy
- `main` → GitLab **`deploy_to_live` 수동**
- `scripts/after_install.sh`: `npm ci` → **`npx prisma generate`** (스키마 push/migrate 없음)

### 프론트

- DB 직접 연결 없음 → DB 배포 작업 없음 (API/WS 배포 후 연동 테스트만)

---

## 3. 변경 유형별 작업

### A. API — 스키마 변경 (Laravel)

1. `database/migrations/xxxx_xx_xx_....php` 작성
2. **QA MySQL**에 반영  
   - QA 서버: `php artisan migrate`  
   - 또는 DBA가 QA에 SQL 실행
3. `git push origin qa` (API 배포)
4. 통합 QA 후 **Live**  
   - Live DB **백업**  
   - `php artisan migrate --force` 또는 DBA SQL  
   - API Live 배포 (팀 절차)

### B. API — 데이터만 변경

- 마이그레이션 없이 SQL/툴로 QA → 검증 → Live
- API 코드 배포는 **로직 변경 시에만**

### C. WebSocket — 스키마 변경 (Prisma)

워크플로는 **DB가 먼저**, 코드는 스키마를 따라감.

```text
1. QA MySQL에 DDL/SQL 적용 (ALTER, CREATE, …)
2. (개발) npx prisma db pull → schema.prisma 갱신
3. 앱 코드 수정 → release/* push → QA CodeDeploy
4. 서버: prisma generate (스키마는 이미 DB에 반영된 상태)
```

- README 기준: 스키마 동기화는 `npx prisma db pull` 패턴
- **`prisma migrate deploy`만 기대하면 안 됨** (CI에 없음)

### D. WebSocket — 데이터만

- SQL로 QA/Live 반영, 코드 배포는 필요 시만

### E. 프론트

- DB 배포 없음. API/WS 계약·URL 변경 시 FE 배포만.

---

## 4. QA → Live 권장 순서 (DB 포함 릴리즈)

```text
[1] QA DB     백업(선택) → migrate/SQL → API(qa) → WS(release/*) → FE(qa) → 통합 테스트
[2] Live DB   백업(필수) → 동일 migrate/SQL
[3] Live 코드 API → WebSocket(main + deploy_to_live 수동) → FE(main)
```

DB와 코드 버전이 어긋나면 API 500, WS `/health` 실패, 채팅·브래킷 오류.

---

## 5. 체크리스트

### QA (DB 변경 있을 때)

- [ ] 변경 SQL/마이그레이션 문서화
- [ ] QA DB 적용 완료
- [ ] 영향 repo 배포: API `qa` / WS `release/*` / FE `qa`
- [ ] qa-tp 등에서 smoke test

### Live

- [ ] Live DB **백업**
- [ ] QA와 동일 스키마/데이터 절차 적용
- [ ] API Live (팀 브랜치·스크립트)
- [ ] WS `main` + GitLab `deploy_to_live` 수동
- [ ] FE `main`
- [ ] `/health`, 핵심 API, 브래킷·채팅 확인

### 로컬 (주의)

- [ ] Live DB에 `artisan migrate` / 임의 DDL **금지**
- [ ] dev DB만 `migrate` 또는 팀이 준 QA dev 인스턴스

---

## 6. 하지 말 것

| 하지 말 것 | 이유 |
|------------|------|
| Git push만으로 DB 스키마 반영 기대 | CI에 migrate 없음 (WS는 generate만) |
| DB 변경 없이 스키마만 다른 코드 배포 | 런타임 오류 |
| `triumph_ai\env`만 수정하고 서버 빌드 env 미반영 | QA/Live URL·키 불일치 |
| WebSocket `qa`만 push하고 QA 배포 기대 | `qa`는 검증만 |
| Live DB 백업 없이 DDL | 롤백 어려움 |

---

## 7. 팀에 확인할 항목

- [ ] QA / Live MySQL 호스트·DB명·계정 (`DB_HOST`, `DATABASE_URL`)
- [ ] `git_deploy_qa.sh` / Live 스크립트에 **`php artisan migrate` 포함 여부**
- [ ] 게임 테이블: Laravel migration vs DBA SQL only
- [ ] WebSocket: DB 선행 vs 코드 선행 팀 규칙
- [ ] Live 롤백·점검 시간·담당자

---

## 8. 관련 문서

- [deployment-playbook.md](./deployment-playbook.md) — §4-5, §4-6, Live 체크리스트
- [service-map.md](./service-map.md) — 연동·env 키
- [HANDOFF.md](./HANDOFF.md) — 배포 깃 역할·Handoff 템플릿
