# =============================================================
#  DevSecOps Local Setup Script for Windows
#  Run this in PowerShell as Administrator
# =============================================================

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "  DevSecOps Local Setup - Windows" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# ── Helper function ───────────────────────────────────────────
function Check-Command($cmd) {
    return (Get-Command $cmd -ErrorAction SilentlyContinue) -ne $null
}

function Print-Step($num, $msg) {
    Write-Host ""
    Write-Host "[$num] $msg" -ForegroundColor Yellow
    Write-Host "---------------------------------------------" -ForegroundColor DarkGray
}

# ── Step 1: Verify prerequisites ─────────────────────────────
Print-Step "1" "Checking prerequisites..."

$missing = @()
if (!(Check-Command "docker"))    { $missing += "Docker Desktop" }
if (!(Check-Command "minikube"))  { $missing += "Minikube" }
if (!(Check-Command "kubectl"))   { $missing += "kubectl" }
if (!(Check-Command "helm"))      { $missing += "Helm" }
if (!(Check-Command "git"))       { $missing += "Git" }

if ($missing.Count -gt 0) {
    Write-Host "❌ Missing tools: $($missing -join ', ')" -ForegroundColor Red
    Write-Host "Please install them and re-run this script." -ForegroundColor Red
    Write-Host ""
    Write-Host "Install Helm:     winget install Helm.Helm" -ForegroundColor White
    Write-Host "Install kubectl:  winget install Kubernetes.kubectl" -ForegroundColor White
    exit 1
}

Write-Host "✅ All prerequisites found!" -ForegroundColor Green

# ── Step 2: Start Minikube ────────────────────────────────────
Print-Step "2" "Starting Minikube..."
minikube start --driver=docker --memory=4096 --cpus=2 --disk-size=20g
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Minikube failed to start. Is Docker Desktop running?" -ForegroundColor Red
    exit 1
}

# Enable required addons
Write-Host "Enabling Minikube addons..." -ForegroundColor Gray
minikube addons enable ingress
minikube addons enable metrics-server
minikube addons enable registry

Write-Host "✅ Minikube running!" -ForegroundColor Green

# ── Step 3: Configure local Docker registry ───────────────────
Print-Step "3" "Setting up local Docker registry..."
docker run -d -p 5001:5000 --name local-registry --restart=always registry:2 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Local registry started on port 5001" -ForegroundColor Green
} else {
    Write-Host "⚠️  Registry may already be running (that's fine)" -ForegroundColor Yellow
}

# ── Step 4: Start Jenkins + SonarQube via Docker Compose ──────
Print-Step "4" "Starting Jenkins and SonarQube..."
Write-Host "Note: First startup may take 3-5 minutes to download images" -ForegroundColor Gray

# Required for SonarQube on Windows
wsl -e sudo sysctl -w vm.max_map_count=262144 2>$null

docker-compose up -d jenkins sonarqube sonar-db
Write-Host "✅ Jenkins and SonarQube starting..." -ForegroundColor Green

# ── Step 5: Create Kubernetes namespace ───────────────────────
Print-Step "5" "Creating Kubernetes namespace..."
kubectl apply -f k8s/namespace.yaml
Write-Host "✅ Namespace 'three-tier' created" -ForegroundColor Green

# ── Step 6: Deploy MongoDB ────────────────────────────────────
Print-Step "6" "Deploying MongoDB to Kubernetes..."
kubectl apply -f k8s/database/mongodb.yaml
Write-Host "Waiting for MongoDB to be ready (this takes ~30s)..." -ForegroundColor Gray
kubectl wait --for=condition=available deployment/mongodb -n three-tier --timeout=120s
Write-Host "✅ MongoDB deployed!" -ForegroundColor Green

# ── Step 7: Install Prometheus + Grafana via Helm ─────────────
Print-Step "7" "Installing Prometheus + Grafana..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
helm install stable prometheus-community/kube-prometheus-stack -n monitoring --wait --timeout=300s
Write-Host "✅ Prometheus + Grafana installed!" -ForegroundColor Green

# ── Step 8: Install ArgoCD ────────────────────────────────────
Print-Step "8" "Installing ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.4.7/manifests/install.yaml
Write-Host "Waiting for ArgoCD pods (this takes ~60s)..." -ForegroundColor Gray
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=180s
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'
Write-Host "✅ ArgoCD installed!" -ForegroundColor Green

# ── Step 9: Build and push images ─────────────────────────────
Print-Step "9" "Building Docker images..."
Write-Host "Building frontend..." -ForegroundColor Gray
docker build -t localhost:5001/frontend:latest ./frontend
docker push localhost:5001/frontend:latest

Write-Host "Building backend..." -ForegroundColor Gray
docker build -t localhost:5001/backend:latest ./backend
docker push localhost:5001/backend:latest

Write-Host "✅ Images built and pushed to local registry!" -ForegroundColor Green

# ── Step 10: Deploy app to Kubernetes ─────────────────────────
Print-Step "10" "Deploying application to Kubernetes..."
kubectl apply -f k8s/backend/deployment.yaml
kubectl apply -f k8s/frontend/deployment.yaml
kubectl apply -f k8s/ingress.yaml
Write-Host "✅ App manifests applied!" -ForegroundColor Green

# ── Step 11: Print access URLs ────────────────────────────────
Print-Step "11" "Setup Complete! Fetching access URLs..."
Write-Host ""

$minikubeIP = minikube ip
Write-Host "=============================================" -ForegroundColor Green
Write-Host "  ✅ ALL SERVICES READY" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  🌐 Frontend App    : http://$minikubeIP (after minikube tunnel)" -ForegroundColor Cyan
Write-Host "  🔧 Backend API     : http://localhost:5000" -ForegroundColor Cyan
Write-Host "  🔨 Jenkins         : http://localhost:8080" -ForegroundColor Cyan
Write-Host "  📊 SonarQube       : http://localhost:9000  (admin/admin)" -ForegroundColor Cyan
Write-Host "  📈 Grafana         : run: minikube service stable-grafana -n monitoring" -ForegroundColor Cyan
Write-Host "  🔄 ArgoCD          : run: minikube service argocd-server -n argocd" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Jenkins password   : run: docker exec devtask-jenkins cat /var/jenkins_home/secrets/initialAdminPassword" -ForegroundColor Yellow
Write-Host "  ArgoCD password    : run: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d" -ForegroundColor Yellow
Write-Host ""
Write-Host "  💡 To expose frontend: run 'minikube tunnel' in a separate terminal" -ForegroundColor White
Write-Host ""
