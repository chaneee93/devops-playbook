# 03. GitHub Actions · OIDC · 보안 게이트

> GitLab CI 파이프라인을 GitHub Actions로 이식하고, OIDC와 보안 스캔 게이트를 적용한 기록

---

## 🎯 핵심 3줄

1. **도구가 아니라 원리 — GitLab CI의 stage가 Actions의 job이 될 뿐, 개념은 같다**
2. **키를 관리하지 말고, 키를 없애라 — OIDC는 키 대신 신원을 증명한다**
3. **게이트는 막는 게 아니라 알려주는 것 — 관찰 → 신규차단 → 등급차단 → 전면적용 순서로**

---

## 🔄 GitLab CI → GitHub Actions 이식 대응표

| GitLab CI | GitHub Actions | 비고 |
|---|---|---|
| `.gitlab-ci.yml` | `.github/workflows/*.yml` | 파일 1개 = 워크플로 1개 |
| stages | — (없음) | `needs`로 순서를 표현 |
| stage: build | job 이름 + needs | jobs 단위로 구성 |
| image: alpine | runs-on: ubuntu-latest | GitHub이 러너 제공 (무료) |
| script: | steps: + run: | |
| artifacts: paths: | upload-artifact / download-artifact | 두 개로 분리 |
| (자동 clone) | actions/checkout@v4 | **명시 필요!** |
| rules: if: | if: github.ref == '...' | |
| when: manual | environment + Required reviewers | 승인자 지정 가능 |
| tags: [docker] | — (불필요) | GitHub 호스팅 러너 사용 시 |
| CI/CD Variables | Secrets / Variables | environment별 분리 가능 |

---

## 🏗 직접 구축한 것

### 구현 범위

- [x] GitHub Actions 기본 워크플로 (build → test → package)
- [x] GitLab CI 파이프라인을 Actions로 이식
- [x] artifact로 job 간 파일 전달 (upload/download)
- [x] environment 승인 게이트 (prod = Required reviewers)
- [x] 보안 스캔 게이트 (Gitleaks 시크릿 스캔 + Trivy IaC 스캔)
- [x] 취약한 코드를 일부러 넣어서 스캔 차단 검증 (Trivy HIGH 6건 탐지)
- [ ] OIDC로 AWS 액세스 키 제거 (AWS IAM 권한 확보 후 진행 예정)

---

## 🔐 OIDC — 키를 없애는 방법 (이론)

### 발상의 전환

| 기존 방식 | OIDC 방식 |
|---|---|
| 키를 만든다 | 키를 만들지 않는다 |
| 키를 CI에 저장한다 | 신원을 증명한다 |
| 키를 마스킹한다 | AWS가 임시 자격증명을 준다|
| 키를 주기적으로 교체한다 | 1시간 뒤 자동 만료된다 |
| **관리 비용이 영원히 든다** | **관리할 것이 없다** |

### 동작 흐름

```
① GitHub Actions → GitHub OIDC Provider : JWT 발급 요청
② OIDC Provider → Actions               : 서명된 JWT (유효 몇 분)
③ Actions → AWS STS                      : JWT 제출
④ AWS STS                                : 서명 · sub 검증
⑤ AWS STS → Actions                      : 임시 자격증명 (기본 1시간)

→ 저장소 어디에도 AKIA로 시작하는 값이 없다
```

### sub 조건 — 넓으면 문 열어 둔 것

| sub 조건 | 보안 등급 |
|---|---|
| `repo:acme/*` | 🔴 위험 — 조직의 아무 저장소 |
| `repo:acme/notes-app:*` | 🟡 주의 — 아무 브랜치 · PR |
| `repo:acme/notes-app:ref:refs/heads/main` | 🟢 안전 — main 브랜치만 |
| `repo:acme/notes-app:environment:prod` | 🟢 가장 안전 — prod 환경 승인 거친 job만 |

---

## 🛡 보안 스캔 4종

| 종류 | 검사 대상 | 잡는 것 |
|---|---|---|
| **SAST** | 내 소스 코드 | SQL 인젝션, 하드코딩 크리덴셜 |
| **SCA** | 내가 쓴 라이브러리 | log4j 같은 알려진 취약 버전 |
| **시크릿 스캔** | 커밋된 모든 텍스트 | AKIA···, 개인키, 토큰 |
| **IaC 스캔** | Terraform · K8s YAML | 0.0.0.0/0 개방, 암호화 미설정 |

### Shift Left — 왜 왼쪽으로 옮기는가

```
로컬 → PR → main 머지 → 스테이징 배포 → 운영 장애
  ←── 비용 싸다                    비용 비싸다 ──→
```

고치는 비용은 오른쪽으로 갈수록 자릿수 단위로 커진다. 게이트는 '통과 못 하게 막는 것'이 아니라 '늦기 전에 알려주는 것'이 목적이다.

### 게이트 도입 전략 (단계적)

| 단계 | 설정 | 기간 |
|---|---|---|
| 1. 관찰 | 스캔은 돌리되 exit-code 0 — 실패시키지 않음 | 1~2주 |
| 2. 신규 차단 | 새로 추가된 취약점만 실패 | 2~4주 |
| 3. 등급 차단 | CRITICAL만 → 이후 HIGH까지 확대 | 1~2개월 |
| 4. 전면 적용 | HIGH 이상 실패 + 예외는 만료일 있는 티켓 | 이후 상시 |

> ⚠️ 1단계를 건너뛰고 바로 차단하면 첫날 200개 실패가 뜨고 게이트가 꺼진다

---

## 🔥 트러블슈팅 (직접 겪은 것들)

| # | 증상 | 원인 | 해결 |
|---|------|------|------|
| 1 | security.yml 워크플로가 Actions 탭에 안 나타남 | WSL에서 파일 생성 후 push가 안 됨 | GitHub 웹에서 직접 파일 생성 |
| 2 | deploy-dev가 ⊘ 스킵됨 | main 브랜치라서 `if: github.ref == 'refs/heads/develop'` 조건 불일치 | 정상 동작 (의도된 스킵) |
| 3 | prod 배포가 자동 실행됨 | environment에 Required reviewers 미설정 | Settings → Environments → prod → 승인자 추가 |
| 4 | Trivy에서 HIGH 6건 실패 | 일부러 넣은 취약 코드 (0.0.0.0/0, S3 public) | 보안 게이트 정상 작동 확인 |

---

## 📁 템플릿

| 파일 | 용도 |
|------|------|
| [01-basic-workflow.yml](./templates/01-basic-workflow.yml) | build → test → package 기본 워크플로 |
| [02-with-deploy.yml](./templates/02-with-deploy.yml) | environment 승인 게이트 + 브랜치 분기 |
| [03-security-gate.yml](./templates/03-security-gate.yml) | 시크릿 스캔 + 취약점 스캔 |
| [04-oidc-aws.yml](./templates/04-oidc-aws.yml) | OIDC로 AWS 접근 (키 없이) |

---

## 📊 Actions 한도 (실습에선 안 걸리지만 운영에서 걸린다)

| 항목 | 한도 |
|------|------|
| job 기본 타임아웃 | 360분 (6시간) |
| 워크플로 실행 전체 최대 | 35일 (승인 대기 포함) |
| 환경 승인 대기 한도 | 30일 |
| matrix 최대 job | 256개 / 실행 |
| artifact 보관 | 기본 90일 |
| 캐시 총 용량 | 저장소당 10GB |
| 미사용 캐시 삭제 | 7일 |
| 동시 job (Free/Team/Enterprise) | 20 / 60 / 500 |
