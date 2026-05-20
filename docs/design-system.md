# Triumph — 디자인 시스템 (UI/UX 산출물)

> **UI/UX** `@ui-ux` 갱신 · **기획/아키텍처** 검토 · **구현 · FE** 적용  
> 코드: `repos/global-triumphserver/src/plugins/vuetify.js`, `src/styles/settings.scss`, `src/styles/tokens.css`, `src/components/CustomUI/`

**Handoff:** [handoffs/E2-design-system.md](./handoffs/E2-design-system.md)  
**페이지 인벤토리:** [page-inventory.md](./page-inventory.md)  
**상태:** ready (UI/UX 1차 완료 — 기획 검토 대기)  
**갱신일:** 2026-05-20

---

## 0. 현황 요약

| 영역 | 상태 |
|------|------|
| 타이포 | `settings.scss` 확정 · `text-tp-*` 사용 |
| 컬러 | `vuetify.js` light 테마 · 역할 규칙 아래 |
| Spacing/Radius | `tokens.css` 초안 (`--tp-space-*`, `--tp-radius-*`) |
| 쇼케이스 | `/design-system` (DEV only) |
| P0 적용 | `/auth/login`, `/event/create` |

`App.vue`는 `theme="light"`이나 `background`=#141319 등 **다크 톤 UI** — Vuetify 테마명과 시각이 다름(문서화만, E5에서 정리).

---

## 1. Color — 역할 표

| 역할 | Vuetify 키 | hex | 용도 |
|------|------------|-----|------|
| Brand / CTA | `triumph`, `primary500` | #4E41DB | 버튼·라디오·체크·강조 (**동일값, prop은 `triumph` 권장**) |
| Link / 하이퍼링크 | `primary` | #4c8cff | `text-primary`, `router-link` |
| Page BG | `background` | #141319 | 로그인 카드·앱 배경 |
| Surface / 필드 BG | `surface`, `gray800` | #3f3f46 | 카드·입력 배경(기본) |
| 본문 텍스트 | `mainText` | #D9D9D9 | 보조 문구 |
| On-surface | `on-surface`, `gray0` | #FFFFFF | 밝은 텍스트·구분선 |
| Border / 비활성 | `gray300`~`gray600` | | `base-color`, dashed border |
| Error | `error`, `red600` | #DB2E30 / #E63333 | 폼 에러 (`TpTextField` 메시지) |
| Modal | `bg-modal` | #1d1e23 | 다이얼로그 |

### `primary` vs `triumph` vs `primary500` (FE 규칙)

1. **제출·CTA·선택 컨트롤** → `color="triumph"` (또는 `text-triumph`)
2. **텍스트 링크·비밀번호 찾기·가입** → `class="text-primary"` (`#4c8cff`)
3. **`primary500` prop** — `triumph`와 동일 hex; **신규 코드는 `triumph`만** (P0에서 Event Create 통일)
4. **hex 직접 입력 금지** — `rgb(var(--v-theme-{key}))` 또는 Vuetify `color` prop
5. **폼 필드** — `variant="outlined"`, `color="triumph"`, `base-color="gray300"`, `bg-color="white"` (라이트 필드 on 다크 페이지)
6. **취소 버튼** — `color="gray700"` + `variant="outlined"`
7. **에러** — `red600`, 아이콘 `tp:alertCircle`
8. **아이콘** — `color="gray500"` (도움말), `tp:*` 커스텀 세트
9. **팔레트 확장** — `primary10`~`primary990`, `gray*` — 쇼케이스·필요 시만
10. **브라켓 D3** — `drawingConfig` 별도 (E2 범위 외)

---

## 2. Typography

정의: `src/styles/settings.scss` → Vuetify `$typography`.

| 클래스 | size (rem) | weight | P0 권장 용도 |
|--------|------------|--------|--------------|
| text-tp-heading-5 | 1.5 | 700 | 페이지 타이틀 (이벤트 생성) |
| text-tp-heading-5 | 1.5~2 | 700 | 로그인 타이틀 (`LoginContent`) |
| text-tp-title-3 | 1.125 | 600 | 섹션 제목·필수 라벨 |
| text-tp-title-2-impact | 1rem | 700 | 로그인 CTA 버튼 |
| text-tp-body-2 ~ 3 | 0.875~1 | 400 | 본문·설명 |
| text-tp-body-1-impact | 0.75 | 600 | 필드 에러 (PC) |
| text-tp-label-2-impact | 0.75 | 600 | 필드 에러 (mobile) |
| text-tp-label-3 | 0.875 | 400 | 캡션·DS 라벨 |

**로그인:** `text-tp-heading-5` + `text-tp-body-3 text-mainText`  
**이벤트 생성:** 섹션 `text-tp-title-3`, 제목 `text-tp-heading-5`

---

## 3. Spacing / Radius (`tokens.css`)

| 토큰 | 값 |
|------|-----|
| `--tp-space-1` ~ `--tp-space-8` | 4, 8, 12, 16, 24, 32, 40, 48px |
| `--tp-radius-sm` ~ `--tp-radius-xl` | 4, 8, 12, 16px |
| 유틸 | `.tp-gap-2`, `.tp-gap-4`, `.tp-radius-md` |

---

## 4. 컴포넌트 인벤토리

전역 등록: `src/components/index.js`.

| 전역명 | 경로 | 용도 | DS |
|--------|------|------|-----|
| TpTextField | CustomUI/TPTextField.vue | 단일행 입력 | P0 표준 |
| TpTextarea | CustomUI/TPTextarea.vue | 다행 입력 | P0 |
| TpDateTimePicker | CustomUI/DateTimePicker/ | 일시 | 이벤트 생성 |
| TpImageUploader | CustomUI/TPImageUploader/ | 배너·아이콘 | 이벤트 생성 |
| TpBottomSheet | CustomUI/TPBottomSheet/ | 모바일 시트 | — |
| TpContainer / TpRow / TpCol | Layout/ | 그리드 | 이벤트 생성 |
| EventCard | CustomUI/Common/EventCard.vue | 목록 카드 | P1 |
| BracketContainer | CustomUI/Bracket/ | 대진 셸 | P1 (로직 X) |
| GameSelectorLighten | CustomUI/Common/ | 게임 선택 | P0 |
| EventThemeButtonGroup | Event/Create/ | 배너 테마 | P0 |

### TpTextField vs v-text-field

| 상황 | 사용 |
|------|------|
| 일반 폼·로그인·이벤트 생성 | **TpTextField** (에러 UI·모바일 details 통일) |
| Vuetify 전용 실험·DS 쇼케이스 | v-text-field 가능 |
| 숨김 validation 필드 | TpTextField `display:none` (기존 패턴) |

---

## 5. 적용 화면 (E2)

| 우선 | path | DS 적용 |
|------|------|---------|
| P0 | `/auth/login` | 완료 |
| P0 | `/event/create` | 완료 (Create/*) |
| P1 | 이벤트 라운지·브라켓 | 대기 |
| P2 | manage, guide | 대기 |

**쇼케이스:** `npm run dev` → http://localhost:3100/design-system (DEV only)

---

## 6. FE 적용 가이드 (요약)

```vue
<!-- CTA -->
<v-btn color="triumph" class="text-tp-title-2-impact">Submit</v-btn>

<!-- 링크 -->
<router-link class="text-primary text-tp-body-2">Forgot password</router-link>

<!-- 입력 -->
<tp-text-field
  variant="outlined"
  color="triumph"
  base-color="gray300"
  bg-color="white"
/>
```

- store / `Bracket.js` / API 필드 변경 없이 스타일만.
- PR 시 [page-inventory.md](./page-inventory.md) 우선순위 준수.

---

## 7. 검토 이력

| 날짜 | 검토자 | 결과 | 메모 |
|------|--------|------|------|
| 2026-05-20 | 기획/아키텍처 | 착수 승인 | E2 Handoff |
| 2026-05-20 | UI/UX | **검토 요청** | P0·쇼케이스·문서 완료 |
