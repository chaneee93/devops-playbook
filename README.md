# 🛠 DevOps Playbook

> 실습하며 직접 구축하고, 삽질하고, 정리한 DevOps 실전 매뉴얼

인프라와 CI/CD를 **직접 구축하며 배운 것들**을 템플릿과 트러블슈팅 기록으로 정리한 저장소입니다.
단순 개념 정리가 아니라, **바로 복붙해서 쓸 수 있는 형태**를 지향합니다.

---

## 📚 목차

| 영역 | 내용 | 상태 |
|------|------|------|
| [01. Docker](./01-docker/) | 이미지 빌드, 볼륨, Compose, 레지스트리 | 🚧 |
| [02. GitLab CI](./02-gitlab-ci/) | 파이프라인 구축, Runner, artifacts/cache | ✅ |
| [03. GitHub Actions](./03-github-actions/) | Actions 이식, OIDC, 보안 게이트 | ✅ |
| [04. 컨테이너 / EKS](./04-container-eks/) | 멀티스테이지, ECR, EKS, IRSA | ✅ |
| [05. K8s 배포 심화](./05-k8s-deploy/) | Probe, Kustomize, Helm | ✅ |
| [06. 설정과 비밀](./06-secrets-eso/) | Parameter Store, Secrets Manager, ESO | ✅ |
| [07. 상태와 비동기](./07-state-async/) | ElastiCache, SQS, SNS, KEDA | ✅ |
| [08. Terraform](./08-terraform/) | IaC, 모듈화, 환경 분리 | 🚧 |
| [09. Kubernetes](./09-kubernetes/) | 클러스터 구성, 매니페스트 | 🚧 |
| [10. AWS](./10-aws/) | 클라우드 인프라 설계 | 🚧 |

---

## 🎯 이 저장소의 원칙

**1. 템플릿 우선**
개념 설명보다 바로 쓸 수 있는 코드를 먼저 둡니다. 실무에서는 처음부터 짜지 않고 템플릿을 갈아끼웁니다.

**2. 트러블슈팅 기록**
"직접 겪은 에러 → 원인 → 해결"을 표로 남깁니다. 같은 문제를 두 번 겪지 않기 위해서입니다.

**3. 왜 쓰는지를 남긴다**
문법은 검색하면 나오지만, "왜 이걸 쓰는지"는 직접 경험해야 압니다. 그 맥락을 기록합니다.

---

## 🚀 빠른 시작

### GitLab CI 템플릿

    02-gitlab-ci/templates/
    ├── 01-basic-pipeline.yml      # build → test → package 기본형
    ├── 02-with-cache.yml          # 의존성 캐싱 적용
    ├── 03-branch-strategy.yml     # 브랜치별 배포 분기
    └── 04-docker-build-push.yml   # Docker 이미지 빌드+푸시

### GitHub Actions 템플릿

    03-github-actions/templates/
    ├── 01-basic-workflow.yml      # build → test → package 기본형
    ├── 02-with-deploy.yml         # environment 승인 게이트
    ├── 03-security-gate.yml       # 시크릿 스캔 + 취약점 스캔
    └── 04-oidc-aws.yml            # OIDC로 AWS 접근 (키 없이)

### 컨테이너 / EKS 템플릿

    04-container-eks/templates/
    ├── Dockerfile.multi           # 멀티스테이지 빌드
    ├── deployment.yaml            # EKS Deployment + IRSA
    └── service.yaml               # ClusterIP Service

### K8s 배포 심화 템플릿

    05-k8s-deploy/templates/
    ├── kustomize/                 # base + overlays (dev/prod)
    └── helm/                      # values 분리 (dev/prod)

### ESO 템플릿

    06-secrets-eso/templates/
    ├── secretstore.yaml           # AWS SM 연결 (IRSA 인증)
    └── externalsecret.yaml        # 비밀 참조 → K8s Secret 자동 생성

### KEDA 템플릿

    07-state-async/templates/
    ├── scaledobject.yaml          # SQS 큐 길이 기반 오토스케일
    └── worker-deployment.yaml     # SQS 워커 Deployment

---

## 🔨 프로젝트 (직접 구축한 것)

| 프로젝트 | 설명 |
|----------|------|
| [notes-app-cicd](./projects/notes-app-cicd/) | GitLab Server+Runner를 Docker로 구축, CI 파이프라인 구현 |
| [notes-app-actions](./projects/notes-app-actions/) | GitHub Actions로 이식, environment 승인 게이트 + 보안 스캔 |
| [notes-app-eks](./projects/notes-app-eks/) | 멀티스테이지 빌드 → ECR push → EKS 배포 → IRSA |
| [notes-app-k8s-deploy](./projects/notes-app-k8s-deploy/) | 무중단 배포 + Kustomize/Helm 환경분리 |
| [notes-app-secrets](./projects/notes-app-secrets/) | ESO로 Git에 비밀 0줄 달성 |
| [notes-app-async](./projects/notes-app-async/) | ElastiCache + SQS/SNS + KEDA 자동 스케일 |

---

## 📈 학습 로그

| 날짜 | 내용 |
|------|------|
| 2026-08 | GitLab CI 파이프라인 구축 (Runner 등록 → 파이프라인 → 브랜치 전략) |
| 2026-08 | GitHub Actions 이식 + environment 승인 게이트 + 보안 스캔 게이트 (Trivy) |
| 2026-08 | 컨테이너 이미지 파이프라인 (멀티스테이지 → ECR → EKS 배포 → IRSA) |
| 2026-08 | K8s 배포 심화 (무중단 4요소 + Kustomize 환경분리 + Helm 차트) |
| 2026-08 | 설정과 비밀 (Parameter Store + Secrets Manager + ESO → Git에 비밀 0줄) |
| 2026-08 | 상태와 비동기 (ElastiCache + SQS/SNS + KEDA → Pod 0~N 자동 스케일) |

---

## 📮 Contact

이 저장소는 지속적으로 업데이트됩니다.
