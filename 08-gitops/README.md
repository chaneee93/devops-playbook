# 08. GitOps 이해 및 전략

> Git이 클러스터 상태를 보증하게 하는 방법론 — 드리프트 제거, Pull 기반, 지속적 조정

---

## 🎯 핵심 3줄

1. **GitOps는 도구가 아니라 'Git이 상태를 보증하게 하는' 방법론이다**
2. **Pull의 본질은 자격증명이 클러스터 밖으로 나가지 않는다는 것이다**
3. **환경은 브랜치가 아니라 디렉터리로 나눈다 — 승격은 태그 한 줄이다**

---

## 📖 핵심 개념

### 드리프트(Drift)

Git에 있는 선언과 실제 클러스터 상태가 다른 것. kubectl edit, 콘솔 수정, HPA 자동 변경 등으로 발생.

| 유형 | 무슨 일이 일어났나 | 에이전트가 할 수 있는 것 |
|------|------------------|-------------------|
| 변경 (modified) | Git에 있는 리소스의 값이 달라졌다 | 되돌린다 (selfHeal) |
| 삭제 (missing) | Git에 있는데 클러스터에 없다 | 다시 만든다 |
| 추가 (extra) | 클러스터에 있는데 Git에 없다 | 지운다 (prune 켤 때만) |
| 무시 대상 | HPA/KEDA가 바꾸는 replicas 등 | ignoreDifferences로 제외 |

### GitOps 4원칙

| 원칙 | 내용 |
|------|------|
| ① 선언적 | "어떻게"가 아니라 "무엇이 되어야 하는가"를 YAML로 |
| ② 버전 관리 | 불변성·이력·감사를 강제하는 저장소(Git)에 보관 |
| ③ 자동 Pull | 에이전트가 승인된 변경을 스스로 가져와 적용 |
| ④ 지속적 조정 | 실제 상태를 관찰하고 선언과 다르면 되돌린다 |

### Push vs Pull

| | Push | Pull |
|---|---|---|
| 자격증명 위치 | CI에 클러스터 접근 권한 | 클러스터 안에만 |
| 클러스터 노출 | 인터넷에서 접근 가능해야 | 안 열어도 됨 |
| 드리프트 감지 | 없음 (배포 시점에만) | 지속적 비교 |
| 클러스터 늘어나면 | CI에 자격증명 N개 | 각 클러스터에 에이전트 |

### 저장소 분리 (3개)

| 저장소 | 내용 | 변경 주체 |
|--------|------|---------|
| 앱 (notes-app) | 소스코드 · Dockerfile · CI | 개발자 매일 커밋 |
| 매니페스트 (notes-manifests) | base / overlays · Helm values | 배포 담당 · 승인 흐름 다름 |
| 부트스트랩 (platform-bootstrap) | ArgoCD 자체 · 공통 컴포넌트 | 플랫폼 팀만 · 변경 드묾 |

### 브랜치 vs 디렉터리

브랜치 분리: 머지 충돌 + cherry-pick 지옥 → **비권장**
디렉터리 분리: main 하나 + overlays/ 아래 환경별 → **권장** (Day 4 Kustomize 구조)

### 승격(Promotion) = 태그 한 줄

```bash
cd overlays/prod
kustomize edit set image notes=<registry>/notes-app:a1b2c3d
git commit -am "promote a1b2c3d to prod"
```

### 롤백 = git revert (reset 아님)

이력을 지우지 않고 되돌린 사실을 커밋으로 남긴다.

### KEDA vs GitOps 충돌

replicas를 Git에서 빼거나 ArgoCD ignoreDifferences로 제외.

### 도입 단계

| 단계 | 기간 | 내용 |
|------|------|------|
| 1. 읽기 전용 | 1~2주 | 차이만 보여줌 |
| 2. dev 자동화 | 2~4주 | dev만 자동 동기화 |
| 3. selfHeal | 1개월 | 손으로 고친 것 자동 원복 |
| 4. prod 확대 | 이후 | 승인 흐름 갖춘 뒤 |

---

## 📁 구축한 것

- [notes-manifests](https://github.com/chaneee93/notes-manifests) — GitOps용 매니페스트 저장소

```
notes-manifests/
├── base/
│   ├── deployment.yaml        # Probe + preStop + ESO envFrom
│   ├── service.yaml
│   ├── externalsecret.yaml    # Git에 비밀 0줄
│   └── kustomization.yaml
├── overlays/dev/
│   └── kustomization.yaml     # replicas: 1, dev 태그
├── overlays/stg/
│   └── kustomization.yaml     # replicas: 2
└── overlays/prod/
    ├── kustomization.yaml     # replicas: 4, prod 태그
    └── patch-resources.yaml   # cpu/memory 상향
```
