# Handoff: E2 디자인 시스템

**상태:** ready (UI/UX 착수)  
**기획 확정일:** 2026-05-20  
**담당:** `@ui-ux` → 완료 후 기획/아키텍처 검토

---

## 목표

기존 Vuetify·CustomUI·`tp-*` 타이포를 **문서화·정리**하고, **구현 가능한** 디자인 시스템으로 만든 뒤 **P0 화면 2곳**에 1차 적용한다.  
**전역 리스킨·브라켓 로직 변경은 하지 않는다.**

---

## 범위

| 포함 | 제외 |
|------|------|
| 토큰 역할 정의·문서 (`design-system.md`) | API / DB / SP |
| `vuetify.js` 색 역할 정리 (삭제 최소) | `store/`, `Bracket.js` 알고리즘 |
| CustomUI hex → theme 치환 (해당 컴포넌트만) | 전 페이지 일괄 CSS |
| ColorTest 또는 DS 쇼케이스 라우트 | Live 배포 (별도 배포 깃) |
| P0: `/auth/login`, 이벤트 생성 플로우 UI | E3 더블 / E4 포인트 |

---

## 기획 검토 요약 (감사)

코드 기준 **부분 DS 존재**, **문서·일관성 부족**.

- 타이포: `settings.scss` — **양호**
- 컬러: `vuetify.js` light 테마 — **풍부하나** `primary`≠`triumph`, light/다크 명칭 혼란
- 컴포넌트: CustomUI 34 + 전역 `TpTextField` 등 — **래퍼 패턴 확립**
- 갭: spacing/radius 토큰, 컴포넌트 가이드, ColorTest 미연결, 하드코딩 hex

상세: [design-system.md §0](../design-system.md)

---

## UI/UX 작업 단계 (`@ui-ux`)

### Phase 1 — 정리·문서 (코드 변경 최소)

1. `vuetify.js` + `settings.scss` 읽고 [design-system.md](../design-system.md) 표 작성  
2. **Color 역할 표** — Brand / Link / BG / Surface / Text / Border / Error  
3. **Typography 매핑** — 화면별 권장 클래스 (login, event create)  
4. `primary` vs `triumph` vs `primary500` **사용 규칙** 10줄  
5. CustomUI 인벤토리 + «언제 TpTextField vs v-text-field»  

### Phase 2 — 쇼케이스 (구현 가능 검증)

1. `ColorTest.vue` 라우터 등록 **또는** `views/DesignSystem/DesignSystemShowcase.vue` 신규  
   - 경로 제안: `/design-system` (dev only, `import.meta.env.DEV` 가드)  
2. 섹션: Color / Typography / Button variants / Form / Card  
3. 로컬 확인: `npm run dev:proxy` → `http://localhost:3100/design-system`

### Phase 3 — 토큰 정합 (선택적 코드)

1. CustomUI 내 하드코딩 hex → `rgb(var(--v-theme-*))` (우선 5파일 이내)  
2. spacing CSS 변수 초안: `src/styles/tokens.css` (신규) + `main.js` import  
3. **전역 리스킨 금지** — Phase 3는 CustomUI + P0 화면만

### Phase 4 — P0 화면 적용

| 화면 | 파일 |
|------|------|
| 로그인 | `components/auth/LoginForm.vue`, `LoginContent.vue`, `views/Auth/LoginPage.vue` |
| 이벤트 생성 | `components/Event/Create/EventCreate*.vue` |

- `color="triumph"`, `text-tp-*`, `TpTextField` 통일  
- Before/After 스크린샷 (QA API 연동 화면)

### Phase 5 — FE Handoff

`design-system.md` §4 FE 가이드 + «P0 적용 diff 요약» → 기획 검토 요청 블록

---

## 완료 조건

- [x] [design-system.md](../design-system.md) §1~§6 채움, 상태 `ready`
- [x] [page-inventory.md](../page-inventory.md) 라우터 인벤토리
- [x] DS 쇼케이스 `/design-system` (DEV)
- [x] P0: login + event create (코드 적용)
- [ ] P0 Before/After 스크린샷 (로컬 캡처 — QA)
- [ ] 기획 탭에「UI/UX 검토 요청」게시

---

## 수정 가능 repo/경로

```
repos/global-triumphserver/
  src/plugins/vuetify.js          # 색 추가·주석만 (대량 삭제 X)
  src/styles/settings.scss
  src/styles/tokens.css           # 신규 가능
  src/style.css                   # spacing 유틸만
  src/components/CustomUI/**
  src/components/auth/**
  src/components/Event/Create/**
  src/views/Test/ColorTest.vue 또는 views/DesignSystem/**
  src/router/index.js             # /design-system 라우트
triumph_ai/docs/design-system.md
```

---

## 배포 메모

- QA: `global-triumphserver` → `qa` (FE만)
- `triumph_ai/docs/*` — 팀 내부 문서 커밋 (선택)

---

## 기획 검토 체크 (완료 후)

- [ ] Handoff 범위 준수 (브라켓 로직·API 없음)
- [ ] `primary`/`triumph` 규칙이 FE가 따르기 쉬운가
- [ ] P0만 touched — diff 크기 적정
- [ ] E3/E4와 충돌 없음
