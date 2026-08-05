# 04. 컨테이너 이미지 파이프라인 · EKS 온보딩 · IRSA

> 멀티스테이지 빌드로 이미지를 40배 줄이고, ECR에 push하고, EKS에 배포하고, IRSA로 키 없이 AWS에 접근한 기록

---

## 🎯 핵심 3줄

1. **이미지는 실행환경 전체를 담는다 — 멀티스테이지로 빌드 도구는 버리고 런타임만 남겨라**
2. **latest는 쓰지 않는다 — 이미지 태그는 커밋 SHA로. 장애 시 추적이 가능해야 한다**
3. **'신원을 증명한다' — GitHub OIDC도, IRSA도, Pod Identity도 전부 같은 원리**

---

## 🏗 직접 구축한 것

- [x] 멀티스테이지 Dockerfile (1.29GB → 7.7MB, **40배 감소**)
- [x] ECR 리포 생성 (IMMUTABLE 태그) + 이미지 push
- [x] eksctl로 EKS 클러스터 생성 (devops-training, 워커 2대)
- [x] Deployment + Service로 EKS에 앱 배포
- [x] IRSA 설정 — Pod에 JWT 토큰 마운트 확인
- [x] MFA 세션 토큰 발급으로 IAM 권한 해결

---

## 📖 핵심 개념

### jar vs 컨테이너 이미지

| 항목 | jar 아티팩트 | 컨테이너 이미지 |
|---|---|---|
| 애플리케이션 코드 | ✅ | ✅ |
| 라이브러리(의존성) | ✅ | ✅ |
| JRE/런타임 버전 | ❌ 서버에 "기대" | ✅ 포함 |
| OS 패키지·타임존 | ❌ "기대" | ✅ 포함 |
| 환경변수·파일 경로 | ❌ "기대" | ✅ 포함 |

> 이미지는 "이 앱이 돌아가는 데 필요한 모든 것"을 통째로 담는다

### 멀티스테이지 빌드

```dockerfile
# Stage 1: builder — 빌드에 필요한 모든 것
FROM golang:1.21 AS builder
WORKDIR /app
COPY go.mod .
COPY main.go .
RUN CGO_ENABLED=0 go build -o app main.go

# Stage 2: runtime — 실행에 필요한 것만
FROM alpine:latest
COPY --from=builder /app/app /app
EXPOSE 8080
CMD ["/app"]
```

| | builder (Stage 1) | runtime (Stage 2) |
|---|---|---|
| 포함 | Go 컴파일러, 소스코드, 빌드 도구 | Alpine + 바이너리만 |
| 크기 | ~1.29GB | ~7.7MB |
| 최종 이미지에 | ❌ 버려짐 | ✅ 이것만 배포 |

### 레이어 캐시 — 잘 안 바뀌는 것부터 COPY

```
❌ 나쁜 예:  COPY . . → RUN go build  (소스 한 줄만 고쳐도 전체 재빌드)
✅ 좋은 예:  COPY go.mod → RUN go mod download → COPY src/ → RUN go build
```

규칙: 잘 안 바뀌는 것부터 COPY. 소스는 항상 마지막.

### 태그 전략

| 태그 | 평가 | 이유 |
|---|---|---|
| `latest` | 🔴 금지 | 뭔지 모름. 롤백 불가 |
| `v1.2.3` | 🟢 권장 | 시맨틱 버저닝 |
| `a1b2c3d` | 🟢 권장 | 커밋 해시 = 코드 추적 |
| `v1.2.3-a1b2c3d` | 🟢 최고 | 버전 + 코드 추적 모두 가능 |

---

## 🌐 EKS 구조

```
AWS 관리 (Control Plane):  apiserver, etcd, scheduler, controller-manager
내 책임 (Data Plane):      관리형 노드그룹(EC2), Fargate, VPC/서브넷/보안그룹
```

VirtualBox K8s와 차이: **kubectl은 동일**, Control Plane을 AWS가 관리해주는 것만 다름.

### EKS 인증 — Access Entries

```bash
# kubeconfig 갱신
aws eks update-kubeconfig --region eu-west-3 --name devops-training

# 확인
kubectl get nodes
```

---

## 🔐 IRSA — Pod가 OIDC로 신원을 증명한다

### GitHub OIDC vs IRSA (같은 원리!)

| | GitHub OIDC | IRSA |
|---|---|---|
| 주체 | GitHub 워크플로 | EKS Pod |
| 증명 | "나 이 리포의 워크플로야" | "나 이 네임스페이스의 SA야" |
| JWT sub | `repo:org/repo:ref:refs/heads/main` | `system:serviceaccount:ns:sa` |
| 결과 | 임시 자격증명 | 임시 자격증명 |

### IRSA 설정 순서

```bash
# 1) OIDC Provider 등록 (클러스터당 1회)
eksctl utils associate-iam-oidc-provider --cluster devops-training --approve

# 2) IAM Role + ServiceAccount 생성 (한 번에)
eksctl create iamserviceaccount \
  --name notes-sa --namespace student16 \
  --cluster devops-training \
  --attach-policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess \
  --approve

# 3) Deployment에서 사용
spec.template.spec.serviceAccountName: notes-sa
```

### IRSA vs EKS Pod Identity

| 항목 | IRSA | Pod Identity |
|---|---|---|
| 필요 인프라 | 클러스터별 OIDC Provider | Pod Identity Agent 애드온 |
| SA 어노테이션 | 필요 | 불필요 |
| 클러스터 간 재사용 | 매번 신뢰정책 수정 | 한 번 설정이면 끝 |
| Fargate | ✅ (IRSA만 가능) | ❌ 미지원 |
| 추천 | 멀티클라우드/Fargate | 새 프로젝트 시작 |

---

## 🔥 트러블슈팅

| # | 증상 | 원인 | 해결 |
|---|------|------|------|
| 1 | ECR CreateRepository AccessDenied | MFA 미인증 (Likelion-Force-MFA 정책) | `aws sts get-session-token`으로 MFA 세션 토큰 발급 후 환경변수 설정 |
| 2 | kubectl not found | eksctl이 클러스터만 만들고 kubectl은 별도 설치 필요 | `curl -LO` + `sudo install`로 kubectl 설치 |
| 3 | docker login WARNING | 자격증명이 암호화 안 됨 경고 | 학습용이면 무시 가능. Login Succeeded가 나오면 정상 |

### MFA 세션 토큰 발급 (자주 쓰는 패턴)

```bash
aws sts get-session-token \
  --serial-number arn:aws:iam::834922934330:mfa/chaneee93 \
  --token-code <6자리_OTP> \
  --duration-seconds 43200

# 출력된 값으로 환경변수 설정
export AWS_ACCESS_KEY_ID=<AccessKeyId>
export AWS_SECRET_ACCESS_KEY=<SecretAccessKey>
export AWS_SESSION_TOKEN=<SessionToken>
```

---

## 📁 템플릿

| 파일 | 용도 |
|------|------|
| [Dockerfile.multi](./templates/Dockerfile.multi) | Go 멀티스테이지 빌드 |
| [deployment.yaml](./templates/deployment.yaml) | EKS Deployment + IRSA |
| [service.yaml](./templates/service.yaml) | ClusterIP Service |

---

## ⚠️ 비용 주의

EKS 클러스터 + EC2 노드는 시간당 과금. 실습 끝나면 반드시 삭제:

```bash
eksctl delete cluster --name devops-training --region eu-west-3
```
