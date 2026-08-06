# 📦 notes-app K8s 배포 심화

> 무중단 배포 4요소 + Kustomize/Helm으로 환경별 분리를 구현한 프로젝트

## 개요

| 항목 | 내용 |
|------|------|
| 기간 | 2026.08 |
| 목표 | 운영 수준의 K8s 배포 구성 + 환경별 분리 |
| 환경 | AWS EKS (eu-west-3) |
| 사용 기술 | Kustomize, Helm, PDB, Probe |

## 구현 상세

### 1. 안정성 설정 (실습 A)
어제 만든 Deployment에 Probe 3종, preStop, PDB, RollingUpdate를 추가하여 무중단 배포 환경을 구성했습니다.

### 2. Kustomize (실습 B)
base(공통 원본 1벌) + overlays(dev/prod)로 환경을 분리했습니다. `kubectl kustomize`로 렌더 결과를 비교하여 같은 base에서 환경별로 다른 결과가 나오는 것을 확인했습니다.

### 3. Helm (실습 C)
차트를 직접 만들고, values-dev.yaml / values-prod.yaml로 환경별 배포를 구현했습니다. `helm template`으로 렌더 결과를 미리 확인하는 습관을 익혔습니다.

## 배운 점

**무중단은 하나가 아니라 네 개가 맞아야 한다.** probe + preStop + graceful shutdown + readiness — 하나라도 빠지면 5xx.

**환경 차이는 복사가 아니라 차이만 관리한다.** Kustomize는 패치 방식, Helm은 템플릿+values 방식. 접근이 다를 뿐 같은 문제를 푼다.
