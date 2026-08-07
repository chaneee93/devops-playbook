# 06. 설정과 비밀 · Secrets Manager · ESO

> Git에 비밀 0줄 — 매니페스트에는 '참조'만, 실제 값은 AWS에

---

## 🎯 핵심 3줄

1. **Secret은 암호화가 아니다 — base64 인코딩일 뿐, 누구나 한 줄이면 읽는다**
2. **분류를 먼저 — 전부 Secrets Manager에 넣으면 비용이 터진다**
3. **Git에는 '어느 키를 가져와라'만 — 저장소가 유출돼도 비밀은 안전하다**

---

## 🏗 직접 구축한 것

- [x] Parameter Store에 설정값 저장 (String + SecureString)
- [x] Secrets Manager에 DB 자격증명 저장 (JSON)
- [x] ESO (External Secrets Operator) Helm으로 설치
- [x] IRSA로 ESO에 AWS 권한 부여 (키 없이)
- [x] SecretStore + ExternalSecret으로 AWS → K8s Secret 자동 동기화
- [x] `grep -ri password` 결과 0줄 달성

---

## 📖 핵심 개념

### 비밀 분류 — 뭘 어디에

| 등급 | 무엇 | 유출되면 | 어디에 |
|------|------|---------|--------|
| 공개 | 앱 이름·포트·로그 레벨 | 아무 일 없음 | 매니페스트에 그대로 |
| 내부 | DB 호스트·버킷 이름 | 아키텍처 노출 | Parameter Store (String) |
| 준민감 | 기능 플래그·외부 API URL | 악용 가능성 | Parameter Store (SecureString) |
| 비밀 | 비밀번호·API 키·개인키 | 즉시 사고! | Secrets Manager |

### Parameter Store vs Secrets Manager

| 항목 | Parameter Store | Secrets Manager |
|------|----------------|-----------------|
| 요금 | Standard 무료 | 시크릿당 과금 |
| 자동 로테이션 | 없음 (직접 구현) | Lambda로 지원 |
| 계정 간 접근 | Advanced 티어만 | 리소스 기반 정책 지원 |
| 값 크기 | 4KB / 8KB | 65KB |
| 적합한 것 | 설정값, 엔드포인트, 튜닝값 | DB 비밀번호, API 키, 인증서 |

> 판단 기준: ① 유출되면 곤란한가 ② 주기적으로 교체해야 하는가 → '예'면 Secrets Manager

### 계층 경로 설계

```
/notes/dev/db/host       → dev DB 호스트
/notes/dev/db/password   → dev DB 비밀번호
/notes/prod/db/host      → prod DB 호스트
/notes/prod/db/password  → prod DB 비밀번호

IAM 정책으로 /notes/dev/* 만 허용 → dev가 prod 비밀번호를 못 봄
```

### ESO (External Secrets Operator)

```
AWS Secrets Manager → ESO (컨트롤러) → K8s Secret → Pod
  실제 값이 여기          자동 동기화       자동 생성     평소처럼 읽음
```

ESO 구성 3요소:
- **SecretStore** — 어디서 가져올까 (AWS SM/PS + IRSA 인증)
- **ExternalSecret** — 무엇을 가져올까 (키 이름 + 갱신 주기)
- **K8s Secret** — ESO가 자동 생성·갱신

### 비밀 교체 시 앱 반영 문제

env로 주입한 값은 프로세스 시작 시 고정. Secret이 바뀌어도 Pod은 옛 값을 씀.

| 방식 | 원리 |
|------|------|
| (a) Reloader | Secret 변경 감지 → 롤링 재시작 |
| (b) 볼륨 마운트 | Secret을 파일로 마운트, kubelet이 자동 갱신 |
| (c) SDK 직접 조회 | 앱이 Secrets Manager API를 직접 호출 |

### Git에 이미 들어간 비밀은?

파일을 지우고 커밋해도 이력에 남는다. 유출된 자격증명은 '지우는 것'이 아니라 '폐기하는 것':
1. 폐기 — 해당 비밀번호·키를 즉시 무효화
2. 교체 — 새 값을 Secrets Manager에 넣는다
3. 확인 — CloudTrail로 그 자격증명이 쓰인 이력 확인
4. 예방 — 시크릿 스캔을 PR 게이트에 붙인다 (Day 2)

---

## 🔥 트러블슈팅

| # | 증상 | 원인 | 해결 |
|---|------|------|------|
| 1 | SecretStore/ExternalSecret CRD not found | ESO 첫 설치 시 취소돼서 CRD 미설치 | `helm uninstall` 후 `--set installCRDs=true`로 재설치 |
| 2 | cannot re-use a name that is still in use | 취소된 Helm 릴리스 찌꺼기 | `helm uninstall` 후 재설치 |
| 3 | apiVersion v1beta1 에러 | ESO 최신 버전은 v1 사용 | `external-secrets.io/v1beta1` → `external-secrets.io/v1` |
| 4 | MFA 세션 만료로 kubectl 실패 | 세션 토큰 12시간 초과 | `unset` 후 `eval $(aws sts get-session-token ...)` |

---

## 📁 템플릿

| 파일 | 용도 |
|------|------|
| [secretstore.yaml](./templates/secretstore.yaml) | SecretStore (AWS SM + IRSA) |
| [externalsecret.yaml](./templates/externalsecret.yaml) | ExternalSecret (비밀 참조) |
