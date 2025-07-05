# EKS-manifest-repo

This repository contains Kubernetes manifests for deployment on Amazon EKS (Elastic Kubernetes Service).

## Getting started

This repository contains Kubernetes manifest files that can be deployed to Amazon EKS. Before deploying, it's recommended to scan these manifests for security issues and best practices using tools like KubeLinter and KubeSec.

## Security Scanning for Kubernetes Manifests

### KubeLinter

[KubeLinter](https://github.com/stackrox/kube-linter) is an open-source tool that checks Kubernetes YAML files and Helm charts for security misconfigurations and best practices.

#### Installation

```bash
# Install KubeLinter using Homebrew
brew install kube-linter

# Or install using curl
curl -L "https://github.com/stackrox/kube-linter/releases/download/v0.6.0/kube-linter-darwin.tar.gz" | tar -xz
sudo mv kube-linter /usr/local/bin/
```

#### Usage

```bash
# Scan a specific manifest file
kube-linter lint k8s-manifests/nginx.yaml

# Scan all manifest files in a directory
kube-linter lint k8s-manifests/

# Scan with a specific configuration
kube-linter lint --config kube-linter.yaml k8s-manifests/
```

#### Sample Configuration

Create a `kube-linter.yaml` file to customize checks:

```yaml
checks:
  addAllBuiltIn: true
  exclude:
    - "unset-cpu-requirements"
    - "unset-memory-requirements"
```

### KubeSec

[KubeSec](https://kubesec.io/) is a security risk analysis tool for Kubernetes resources that can identify security issues in your manifests.

#### Installation

```bash
# Install using curl
curl -s https://raw.githubusercontent.com/controlplaneio/kubesec/master/install.sh | bash

# Or using Docker
docker pull kubesec/kubesec:v2
```

#### Usage

```bash
# Scan a specific manifest file
kubesec scan k8s-manifests/nginx.yaml

# Using Docker
docker run -i kubesec/kubesec:v2 scan /dev/stdin < k8s-manifests/nginx.yaml

# Scan multiple files
kubesec scan k8s-manifests/nginx.yaml k8s-manifests/node.yaml
```

## Setting up Secure-EKS-Deployment Pipeline

**Step1:** Fork the repository or clone it and push it into your version control system

**Step2:** Create CodeConnection to your source code (EKS-manifest) repository.
https://us-east-2.console.aws.amazon.com/codesuite/settings/connections?region=us-east-2

**Step3:** Run the CloudFormation template with the below config: Open the AWS CloudFormation console

- Click "Create stack" > "With new resources (standard)"
- Select "Upload a template file"
- Upload your secure-eks-pipeline.yaml file from your repo.
- Click "Next"
- Enter a stack name (e.g., "secure-eks-pipeline")
- Enter your CodeStar connection ARN in the parameters section
- Enter you repo name and owner details
- Click "Next" through the remaining screens
- Check the acknowledgment for IAM resources and click "Create stack"

**Step4:** Monitor the stack creation and verify the newly created pipeline "Secure-EKS-Deployements-CF"

***

## ⚠️ Important Pipeline Behavior Notice

**The Codepipeline in this repository is currently configured to continue even when security scan errors are detected.** This is intentional for demonstration purposes, but should be modified for production use as per the usecase.

### Current Pipeline Behavior:
- KubeLinter scan results are displayed but don't fail the pipeline
- KubeSec scan results are shown but don't block deployment
- Semgrep and other security scans continue pipeline execution regardless of findings

## Common Issues Found in This Repository

Based on the manifest files in this repository, here are some potential issues that security scanning might identify:

1. In `node.yaml`:
   - Container runs with `privileged: true` which grants extensive permissions
   - Uses `readOnlyRootFilesystem: false` which allows writing to the filesystem
   - No resource limits defined

2. In `nginx.yaml`:
   - No security context defined
   - No resource limits specified
   - No liveness/readiness probes configured

### For Production Use:

**Option 1: Fail Pipeline on Any Security Issues**
Update your `buildspec.yaml` file to exit with non-zero status when security issues are found:

```yaml
phases:
  build:
    commands:
      # KubeLinter scan - fail on any issues
      - kube-linter lint k8s-manifests/ || exit 1
      
      # KubeSec scan - fail if score below threshold
      - |
        for file in k8s-manifests/*.yaml; do
          score=$(kubesec scan "$file" | jq '.[0].score')
          if [ "$score" -lt 5 ]; then
            echo "KubeSec score $score is below threshold of 5 for $file"
            exit 1
          fi
        done
```

**Option 2: Set KubeSec Score Threshold**
Configure a minimum security score (e.g., 5 out of 10) below which the pipeline fails:

```yaml
# Add this to your buildspec.yaml
- |
  KUBESEC_THRESHOLD=5
  for manifest in k8s-manifests/*.yaml; do
    SCORE=$(kubesec scan "$manifest" | jq -r '.[0].score // 0')
    echo "KubeSec score for $manifest: $SCORE"
    if [ "$SCORE" -lt "$KUBESEC_THRESHOLD" ]; then
      echo "❌ Security score $SCORE is below threshold $KUBESEC_THRESHOLD"
      exit 1
    fi
  done
```


## Security Best Practices for EKS Manifests

When creating Kubernetes manifests for EKS, consider the following security best practices that KubeLinter and KubeSec will check for:

1. **Resource Limits**: Always set CPU and memory limits for containers to prevent resource exhaustion attacks.
2. **Security Context**: Configure appropriate security contexts to restrict container privileges.
3. **Read-only Root Filesystem**: Use read-only root filesystems when possible.
4. **Non-root Users**: Run containers as non-root users.
5. **Network Policies**: Define network policies to restrict pod-to-pod communication.
6. **RBAC**: Use Role-Based Access Control with least privilege principle.
7. **Secrets Management**: Never store secrets in plain text within manifests.
8. **Latest Tags**: Avoid using `latest` tags for container images.
9. **Liveness/Readiness Probes**: Implement health checks for better reliability.
10. **Pod Security Standards**: Follow Kubernetes Pod Security Standards.