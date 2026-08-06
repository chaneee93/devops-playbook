# 05. K8s 배포 심화 · Kustomize · Helm

> 무중단 배포 4요소를 적용하고, Kustomize와 Helm으로 환경별 분리를 구현한 기록

---

## 🎯 핵심 3줄

1. **무중단은 '설정 하나'가 아니라 '네 개가 다 맞아야' 성립한다**
2. **환경 차이는 복사가 아니라 '차이만 따로' 로 관리한다**
3. **Secret은 암호화가 아니다 — base64 인코딩일 뿐**

---

## 🏗 직접 구축한 것

- [x] Probe 3종 (startup/readiness/liveness) 적용
- [x] preStop + terminationGracePeriodSeconds 종료 처리
- [x] PDB (PodDisruptionBudget) 설정
- [x] RollingUpdate (maxSurge:1, maxUnavailable:0)
- [x] Kustomize base + overlays (dev/prod 분리)
- [x] Helm 차트 생성 + values 분리 (dev/prod)
- [x] 렌더 결과 비교 (kubectl kustomize / helm template)

---

## 📖 핵심 개념

### 무중단 배포 4요소

| 요소 | 역할 | 없으면? |
|------|------|---------|
| Probe 3종 | startup(기동대기), readiness(트래픽제어), liveness(생존확인) | 준비 안 된 Pod에 트래픽 → 5xx |
| preStop 훅 | SIGTERM 전에 sleep → LB 전파 시간 확보 | LB가 죽은 Pod에 보냄 → 5xx |
| graceful shutdown | 진행 중 요청 마저 처리 후 종료 | 응답 중간에 끊김 → 5xx |
| readinessProbe | 새 Pod 준비될 때까지 트래픽 차단 | 미완성 Pod에 트래픽 → 5xx |

### Probe 3종 상세

| Probe | 질문 | 실패 시 | 경로 예시 |
|-------|------|---------|----------|
| startup | 기동 끝났나? | 다른 probe 시작 안 함 | /health/liveness |
| readiness | 트래픽 받을 준비? | Endpoint에서 제거 (Pod 안 죽임) | /health/readiness (DB 포함) |
| liveness | 살아 있나? | 컨테이너 재시작 (죽이고 새로) | /health/liveness (프로세스만) |

> readiness는 DB 연결까지, liveness는 프로세스 생존만 — 경로를 나눠야 한다

### QoS 클래스

| 클래스 | 조건 | 노드 압박 시 |
|--------|------|-------------|
| Guaranteed | requests = limits | 가장 마지막에 죽음 |
| Burstable | requests < limits | 중간 |
| BestEffort | 둘 다 없음 | **가장 먼저 죽음!** |

### PDB (PodDisruptionBudget)

"최소 N개는 반드시 살아 있어야 한다"는 약속. kubectl drain(노드 업그레이드) 시 Pod이 한꺼번에 죽는 것을 방지.

⚠️ replicas 1개짜리에 minAvailable: 1 걸면 drain이 영원히 안 끝남!

### Secret ≠ 암호화

K8s Secret은 base64 인코딩일 뿐. `base64 -d` 한 줄이면 읽힌다. 진짜 시크릿 관리는 Parameter Store · Secrets Manager · External Secrets Operator로.

---

## 🔄 Kustomize vs Helm 비교

| 관점 | Kustomize | Helm |
|------|-----------|------|
| 접근 방식 | 선언적 오버레이 (패치) | 템플릿 엔진 (Go template) |
| 입력 파일 | 항상 유효한 YAML | 그 자체로는 유효하지 않음 |
| 설치 | kubectl 내장 (apply -k) | 별도 바이너리 |
| 배포 이력 | 없음 (Git 이력이 곧 이력) | 릴리스 저장 → rollback 가능 |
| 값 주입 | patch · images · replicas | values 계층 + --set |
| 추천 | 우리 앱을 우리 환경에 배포 | 차트 패키징 · 서드파티 앱 설치 |

> 둘은 배타적이지 않다 — 함께 쓸 수 있다

---

## 📖 kubectl apply의 이해

```
kubectl apply = "이 상태가 되어야 해"라고 선언

같은 이름 없으면 → 새로 생성
같은 이름 있으면 → 차이점만 업데이트 (RollingUpdate)
```

K8s 리소스(Pod, Service) 변경은 AWS 인프라(VPC, EC2)와 별개:
```
eksctl / Terraform  → AWS 인프라 (VPC, EC2 노드) 관리
kubectl / Kustomize / Helm → K8s 리소스 (Pod, Service) 관리
```

---

## 🔥 트러블슈팅

| # | 증상 | 원인 | 해결 |
|---|------|------|------|
| 1 | helm template 에러: missing value for command | `cat > << 'EOF'`에서 `{{ }}`가 셸 해석됨 | 구분자를 `HELM`으로 변경 |
| 2 | Pod 무한 재시작 | startup probe 없이 liveness만 설정, 기동 시간 부족 | startup probe 추가 (failureThreshold × periodSeconds ≥ 기동시간) |
| 3 | 배포 시 5xx 발생 | preStop 없음 → LB 전파 전에 Pod 종료 | preStop: sleep 5 추가 |

---

## 📁 템플릿

### Kustomize

| 파일 | 용도 |
|------|------|
| [base/](./templates/kustomize/base/) | 공통 원본 (deployment + service) |
| [overlays/dev/](./templates/kustomize/overlays/dev/) | dev 환경 차이 |
| [overlays/prod/](./templates/kustomize/overlays/prod/) | prod 환경 차이 + 리소스 패치 |

### Helm

| 파일 | 용도 |
|------|------|
| [values.yaml](./templates/helm/values.yaml) | 기본값 |
| [values-dev.yaml](./templates/helm/values-dev.yaml) | dev 환경 값 |
| [values-prod.yaml](./templates/helm/values-prod.yaml) | prod 환경 값 |
