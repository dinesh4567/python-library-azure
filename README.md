# Digital Library Microservices on Azure AKS

A Python Flask digital library deployed to **Azure Kubernetes Service**, with the
cluster and container registry provisioned by Terraform and delivered through a
Jenkins pipeline that builds, scans and pushes to Azure Container Registry.

This is the Azure counterpart to my
[AWS EKS build of the same application](https://github.com/dinesh4567/AWS-Python-microservices-app) —
same architecture, two providers, deliberately built to compare how the pieces map.

## Architecture

![Architecture](architecture/architecture.png)

Users reach the frontend through the AKS load balancer. The frontend calls three
backend Flask services, each of which talks to a MySQL pod. Configuration comes
from a ConfigMap, credentials from a Secret.

| Service | Port | Purpose |
|---|---:|---|
| Frontend | 5000 | Web UI |
| Auth service | 5001 | Signup and signin |
| Book service | 5002 | Book catalogue |
| Borrow service | 5003 | Borrowing records |
| MySQL | 3306 | Persistent data |

## CI/CD pipeline

![Pipeline](architecture/pipeline.png)

The Jenkins pipeline runs:

1. Clean workspace and checkout
2. SonarQube analysis with a blocking quality gate
3. Build images for all five components
4. Trivy scan for HIGH and CRITICAL vulnerabilities
5. Azure login via service principal, then ACR login
6. Push tagged images to Azure Container Registry
7. Fetch AKS credentials
8. Substitute the registry and tag into the manifests
9. Apply manifests and verify pods, services and deployments

Images are tagged with `${BUILD_NUMBER}` rather than `latest`, so every deploy is
traceable to a specific build.

## Stack

| Area | Technology |
|---|---|
| Cloud | Microsoft Azure |
| Infrastructure as Code | Terraform |
| Orchestration | Azure Kubernetes Service (AKS) |
| Registry | Azure Container Registry (ACR) |
| CI/CD | Jenkins |
| Code quality | SonarQube |
| Image scanning | Trivy |
| Application | Python Flask |
| Database | MySQL |

## Repository layout

```text
├── architecture/           # Architecture and pipeline diagrams
├── terraform/              # Resource group, AKS cluster, ACR
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf
│   └── terraform.tfvars.example
├── k8s/
│   ├── namespace.yaml
│   ├── application/        # Shared ConfigMap and Secret template
│   ├── database/           # MySQL deployment, service, config, secret template
│   ├── auth/  book/  borrow/  frontend/
│   └── ingress/
├── auth-service/  book-service/  borrow-service/  frontend/  database/
└── Jenkinsfile
```

## Deploy

### 1. Provision infrastructure

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # then fill in your subscription_id
terraform init
terraform plan
terraform apply
```

This creates the resource group, the AKS cluster and an ACR instance. Take the
ACR name from the Terraform output — the Jenkins pipeline needs it.

### 2. Configure Jenkins

| Setting | Value |
|---|---|
| Credential `jenkins-sp` | Azure service principal (username/password) |
| Credential `azure-tenant-id` | Your Azure AD tenant ID |
| Pipeline parameter `ACR_NAME` | ACR name from the Terraform output |
| Tool `sonar` | SonarQube scanner installation |

### 3. Create the Secrets

Secret manifests in this repository are **templates**. Create the real ones at
deploy time:

```bash
kubectl apply -f k8s/namespace.yaml

kubectl create secret generic mysql-secret -n library \
  --from-literal=MYSQL_ROOT_PASSWORD='<choose-a-strong-password>'

kubectl create secret generic app-secret -n library \
  --from-literal=DB_PASSWORD='<same-database-password>' \
  --from-literal=FLASK_SECRET_KEY="$(openssl rand -hex 32)"
```

### 4. Deploy

Run the Jenkins pipeline, or apply manually:

```bash
kubectl apply -f k8s/database/
kubectl apply -f k8s/application/
kubectl apply -f k8s/auth/ -f k8s/book/ -f k8s/borrow/ -f k8s/frontend/

kubectl get pods,svc -n library
```

### 5. Tear down

```bash
cd terraform
terraform destroy
```

## AWS vs Azure — what changed

Building the same application on both providers made the differences concrete:

| Concern | AWS | Azure |
|---|---|---|
| Cluster | EKS + managed node group | AKS, node pool managed by the cluster resource |
| Registry | ECR, one repository per service | ACR, single registry with per-image paths |
| Networking | VPC, subnets, IGW and NAT declared explicitly | AKS provisions the VNet unless overridden |
| Cluster auth | `aws eks update-kubeconfig` | `az aks get-credentials` |
| Registry auth | `aws ecr get-login-password` | `az acr login` |
| Storage class | `gp2` | `managed-csi` / `default` |

The Terraform for AKS is markedly shorter, because the managed service takes over
networking that EKS makes you declare.

## Fixes applied

| Issue | Fix |
|---|---|
| Secret manifests committed with real values (`DB_PASSWORD: root`, `MYSQL_ROOT_PASSWORD: root`) | Replaced with `secret.example.yaml` templates; real Secrets created at deploy time and gitignored |
| Azure AD tenant ID hardcoded in the Jenkinsfile | Read from the `azure-tenant-id` Jenkins credential |
| `ACR_NAME = 'TO_BE_CREATED_BY_TERRAFORM'` | Declared as a build parameter |
| `//` and `/* */` used as comments inside `sh '''...'''` blocks | These are not shell syntax — the shell would try to execute them. Converted to `#` comments |
| `k8s/frontend/deployment.yaml` was **invalid YAML** — the `FLASK_SECRET_KEY` env entry was indented 16 spaces instead of 8 | `kubectl apply -f k8s/frontend/` failed outright. Indentation corrected; all manifests now parse |

## Known limitations

- The Ingress manifest exists but is not applied by the pipeline; the frontend is
  reached through a LoadBalancer Service.
- No TLS. Production would need cert-manager or an Application Gateway with a
  certificate.
- The application connects to MySQL as `root`. A dedicated least-privilege user
  would be better.
- MySQL runs as a Deployment with no PersistentVolumeClaim, so data does not
  survive a pod restart. The AWS build has the same gap; my
  [PHP project](https://github.com/dinesh4567/php-bloodbank-kubernetes) shows the
  StatefulSet approach that fixes it.

## Next steps

- Move MySQL to a StatefulSet with a `volumeClaimTemplates` PVC
- Enable the Ingress with TLS via cert-manager
- Store secrets in Azure Key Vault via the Secrets Store CSI driver
- Package the manifests as a Helm chart and sync with Argo CD, matching the AWS build
- Add Prometheus and Grafana, or wire up Azure Monitor for containers
