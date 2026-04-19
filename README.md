# 🚀 DevSecOps Three-Tier Project — Local Setup (Windows)

A full DevSecOps pipeline running **100% locally** on Windows using Docker, Minikube, Jenkins, ArgoCD, Prometheus, and Grafana. No AWS required.

---

## 📐 Architecture

```
Your Code (Git push)
      │
      ▼
 Jenkins (CI)  ──────►  SonarQube (code scan)
      │
      ▼
 Trivy (image scan)
      │
      ▼
 Local Docker Registry (localhost:5001)
      │
      ▼
 ArgoCD (GitOps) ──── watches your Git repo
      │
      ▼
 Minikube (local Kubernetes)
  ├── Frontend Pod  (React + Nginx)
  ├── Backend Pod   (Node.js + Express)
  ├── MongoDB Pod   (with PV + PVC)
  └── Monitoring    (Prometheus + Grafana)
```

---

## 🛠️ Prerequisites

Install these **before** starting:

| Tool | Download | Purpose |
|------|----------|---------|
| Docker Desktop | https://www.docker.com/products/docker-desktop | Run containers |
| Minikube | https://minikube.sigs.k8s.io/docs/start | Local Kubernetes |
| kubectl | `winget install Kubernetes.kubectl` | K8s CLI |
| Helm | `winget install Helm.Helm` | K8s package manager |
| Git | https://git-scm.com | Version control |
| Node.js 20+ | https://nodejs.org | Local dev |

> ⚠️ Open Docker Desktop and make sure it is **running** before continuing.

---

## 📁 Project Structure

```
devsecops-project/
├── frontend/                  # React app
│   ├── src/
│   │   ├── App.jsx
│   │   ├── App.css
│   │   └── main.jsx
│   ├── Dockerfile
│   ├── nginx.conf
│   ├── vite.config.js
│   └── package.json
│
├── backend/                   # Node.js Express API
│   ├── src/
│   │   ├── app.js
│   │   ├── models/Task.js
│   │   └── routes/
│   │       ├── tasks.js
│   │       └── health.js
│   ├── Dockerfile
│   └── package.json
│
├── k8s/                       # Kubernetes manifests
│   ├── namespace.yaml
│   ├── ingress.yaml
│   ├── argocd-apps.yaml
│   ├── database/
│   │   └── mongodb.yaml       # PV + PVC + Deployment + Service
│   ├── backend/
│   │   └── deployment.yaml
│   └── frontend/
│       └── deployment.yaml
│
├── jenkins/
│   ├── Jenkinsfile-frontend
│   └── Jenkinsfile-backend
│
├── docker-compose.yml         # Local dev: Jenkins + SonarQube + DBs
├── setup.ps1                  # One-click setup script
└── README.md
```

---

## 🔢 STEP-BY-STEP INSTRUCTIONS

### PHASE 1 — Clone & First Look

---

#### Step 1 — Clone the repository

Open **PowerShell** (not CMD) and run:

```powershell
git clone https://github.com/YOUR_USERNAME/devsecops-project.git
cd devsecops-project
```

> 💡 If you don't have a GitHub repo yet, create one at github.com, then push this project:
> ```powershell
> git init
> git add .
> git commit -m "initial commit"
> git remote add origin https://github.com/YOUR_USERNAME/devsecops-project.git
> git push -u origin main
> ```

---

### PHASE 2 — Run App Locally (Without Kubernetes)

This is the fastest way to verify the code works.

---

#### Step 2 — Start all services with Docker Compose

```powershell
# In the project root folder:
docker-compose up -d mongodb backend frontend
```

Wait about 30 seconds, then open:
- **Frontend**: http://localhost:3000
- **Backend API**: http://localhost:5000
- **Health check**: http://localhost:5000/health

You should see the DevTask app. Try adding and deleting tasks to confirm frontend ↔ backend ↔ MongoDB all work.

---

#### Step 3 — Start Jenkins and SonarQube

```powershell
docker-compose up -d jenkins sonarqube sonar-db
```

> ⚠️ SonarQube needs extra memory. If it crashes, run this first:
> ```powershell
> # In WSL terminal (Windows Subsystem for Linux):
> wsl -e sudo sysctl -w vm.max_map_count=262144
> ```

Wait 2–3 minutes, then open:
- **Jenkins**: http://localhost:8080
- **SonarQube**: http://localhost:9000 (login: admin / admin)

Get Jenkins initial password:
```powershell
docker exec devtask-jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

---

### PHASE 3 — Jenkins Setup

---

#### Step 4 — Configure Jenkins

1. Open http://localhost:8080
2. Paste the admin password from Step 3
3. Click **"Install suggested plugins"** and wait
4. Create your admin account
5. Go to **Manage Jenkins → Plugins → Available Plugins**

Install these plugins (search each one):
- `SonarQube Scanner`
- `OWASP Dependency-Check`
- `Docker Pipeline`
- `NodeJS`
- `Git`

Click **Install without restart**, then restart Jenkins.

---

#### Step 5 — Configure Jenkins Tools

Go to **Manage Jenkins → Tools**:

**NodeJS:**
- Click "Add NodeJS"
- Name: `NodeJS-20`
- Version: `20.x`

**SonarQube Scanner:**
- Click "Add SonarQube Scanner"
- Name: `SonarScanner`
- Install automatically ✅

**OWASP Dependency-Check:**
- Click "Add Dependency-Check"
- Name: `DP-Check`
- Install automatically ✅

Click **Save**.

---

#### Step 6 — Configure SonarQube in Jenkins

**In SonarQube (http://localhost:9000):**
1. Login as admin/admin → change password when prompted
2. Go to **Administration → Security → Users → admin → Tokens**
3. Generate a token called `jenkins-token` → **copy it**
4. Go to **Administration → Configuration → Webhooks**
5. Click "Create" → Name: `jenkins` → URL: `http://jenkins:8080/sonarqube-webhook/`

**In Jenkins:**
1. Go to **Manage Jenkins → System**
2. Find **SonarQube installations**
3. Click "Add SonarQube"
   - Name: `SonarQube`
   - Server URL: `http://sonarqube:9000`
   - Server authentication token: Add → Secret text → paste your token → ID: `sonar-token`
4. Click **Save**

---

#### Step 7 — Create Jenkins Pipelines

**Frontend Pipeline:**
1. Click **New Item** → Name: `devtask-frontend` → Pipeline → OK
2. Under **Pipeline**, select **"Pipeline script from SCM"**
3. SCM: Git → Repository URL: your GitHub URL
4. Script Path: `jenkins/Jenkinsfile-frontend`
5. Click **Save** → **Build Now**

**Backend Pipeline:**
1. Repeat above with name `devtask-backend`
2. Script Path: `jenkins/Jenkinsfile-backend`

---

### PHASE 4 — Kubernetes with Minikube

---

#### Step 8 — Start Minikube

Open a **new PowerShell window**:

```powershell
# Start Minikube with enough resources
minikube start --driver=docker --memory=4096 --cpus=2 --disk-size=20g

# Enable required addons
minikube addons enable ingress
minikube addons enable metrics-server

# Verify it's running
kubectl get nodes
# Expected output:
# NAME       STATUS   ROLES           AGE   VERSION
# minikube   Ready    control-plane   1m    v1.28.x
```

---

#### Step 9 — Set up Local Docker Registry for Minikube

Minikube needs to pull images. We use a local registry:

```powershell
# Start local registry
docker run -d -p 5001:5000 --name local-registry --restart=always registry:2

# Tell Minikube to trust the local registry
minikube ssh "echo '{\"insecure-registries\":[\"host.minikube.internal:5001\"]}' | sudo tee /etc/docker/daemon.json && sudo systemctl restart docker"
```

---

#### Step 10 — Build and Push Images to Local Registry

```powershell
# Build frontend image
docker build -t localhost:5001/frontend:latest ./frontend
docker push localhost:5001/frontend:latest

# Build backend image
docker build -t localhost:5001/backend:latest ./backend
docker push localhost:5001/backend:latest

# Verify images are in registry
curl http://localhost:5001/v2/_catalog
# Expected: {"repositories":["backend","frontend"]}
```

---

#### Step 11 — Deploy to Kubernetes

```powershell
# Create namespace
kubectl apply -f k8s/namespace.yaml

# Deploy MongoDB (with persistent storage)
kubectl apply -f k8s/database/mongodb.yaml

# Wait for MongoDB to be ready
kubectl wait --for=condition=available deployment/mongodb -n three-tier --timeout=120s

# Deploy backend
kubectl apply -f k8s/backend/deployment.yaml

# Deploy frontend
kubectl apply -f k8s/frontend/deployment.yaml

# Apply ingress
kubectl apply -f k8s/ingress.yaml

# Check everything is running
kubectl get all -n three-tier
```

Expected output:
```
NAME                            READY   STATUS    RESTARTS
pod/backend-xxx                 1/1     Running   0
pod/frontend-xxx                1/1     Running   0
pod/mongodb-xxx                 1/1     Running   0
```

---

#### Step 12 — Access the App in Minikube

**Option A — NodePort (simplest):**
```powershell
minikube service frontend-service -n three-tier
# This opens the browser automatically!
```

**Option B — Ingress with tunnel:**
```powershell
# Run this in a separate PowerShell window (keep it open):
minikube tunnel

# Add to Windows hosts file (run PowerShell as Administrator):
Add-Content -Path "C:\Windows\System32\drivers\etc\hosts" -Value "127.0.0.1 devtask.local"
Add-Content -Path "C:\Windows\System32\drivers\etc\hosts" -Value "127.0.0.1 api.devtask.local"

# Then open: http://devtask.local
```

---

### PHASE 5 — Monitoring (Prometheus + Grafana)

---

#### Step 13 — Install Prometheus and Grafana

```powershell
# Add Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create monitoring namespace
kubectl create namespace monitoring

# Install the full monitoring stack
helm install stable prometheus-community/kube-prometheus-stack -n monitoring

# Wait for pods
kubectl get pods -n monitoring --watch
# (Press Ctrl+C when all show Running)
```

---

#### Step 14 — Access Grafana

```powershell
# Open Grafana in browser
minikube service stable-grafana -n monitoring
```

- Username: `admin`
- Password: `prom-operator`

**Import a dashboard:**
1. Click the `+` icon → Import
2. Enter dashboard ID: `3119` (Kubernetes cluster monitoring)
3. Select Prometheus as data source → Import

---

### PHASE 6 — ArgoCD GitOps

---

#### Step 15 — Install ArgoCD

```powershell
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.4.7/manifests/install.yaml

# Wait for it to be ready
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=180s

# Expose as NodePort
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'

# Open in browser
minikube service argocd-server -n argocd
```

---

#### Step 16 — Get ArgoCD Password and Login

```powershell
# Get the auto-generated admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | `
  ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
```

Login with:
- Username: `admin`
- Password: (output from above)

---

#### Step 17 — Connect ArgoCD to Your Git Repo

1. In ArgoCD UI → **Settings → Repositories → Connect Repo**
2. Method: HTTPS
3. Repository URL: `https://github.com/YOUR_USERNAME/devsecops-project`
4. If private repo: enter your GitHub username + Personal Access Token

---

#### Step 18 — Deploy Apps via ArgoCD

**Update the repo URL first:**
```powershell
# Edit k8s/argocd-apps.yaml and replace YOUR_USERNAME with your GitHub username
# Then apply:
kubectl apply -f k8s/argocd-apps.yaml
```

In the ArgoCD UI you will see 4 apps:
- `devtask-database`
- `devtask-backend`
- `devtask-frontend`
- `devtask-ingress`

Click **Sync** on each one. ArgoCD will now deploy from your Git repo automatically on every push! 🎉

---

## 🌀 The Full GitOps Flow (After Setup)

```
1. You write code and git push
          │
          ▼
2. Jenkins detects the push (webhook or poll)
          │
          ▼
3. Jenkins runs:
   ├── npm install + lint
   ├── SonarQube code scan
   ├── docker build
   ├── Trivy image scan
   ├── docker push → localhost:5001
   └── updates image tag in k8s/*.yaml → git push
          │
          ▼
4. ArgoCD detects the manifest change in Git
          │
          ▼
5. ArgoCD deploys new pods to Minikube
          │
          ▼
6. Prometheus scrapes metrics from new pods
          │
          ▼
7. Grafana shows live dashboards
```

---

## 🔍 Useful Commands

```powershell
# See all running pods
kubectl get pods -n three-tier

# See logs from backend
kubectl logs -l app=backend -n three-tier --tail=50

# Restart a deployment
kubectl rollout restart deployment/backend -n three-tier

# See all services
kubectl get svc -n three-tier

# Describe a pod (debug issues)
kubectl describe pod <pod-name> -n three-tier

# Stop Minikube
minikube stop

# Stop Docker Compose services
docker-compose down

# Delete everything from Kubernetes
kubectl delete namespace three-tier
```

---

## ❓ Troubleshooting

| Problem | Fix |
|---------|-----|
| SonarQube won't start | Run `wsl -e sudo sysctl -w vm.max_map_count=262144` |
| Images not found in Minikube | Re-run `minikube ssh` registry setup in Step 9 |
| Jenkins can't reach SonarQube | Use `http://sonarqube:9000` (Docker network name), not localhost |
| Backend can't reach MongoDB | Check `mongodb-service` is Running: `kubectl get svc -n three-tier` |
| ArgoCD app OutOfSync | Click Sync in ArgoCD UI, or check Git repo URL is correct |
| minikube tunnel asks for password | Run PowerShell as Administrator |

---

## 📊 Service Summary

| Service | URL | Login |
|---------|-----|-------|
| Frontend | `minikube service frontend-service -n three-tier` | — |
| Backend API | http://localhost:5000 | — |
| Jenkins | http://localhost:8080 | admin / see Step 3 |
| SonarQube | http://localhost:9000 | admin / admin |
| Grafana | `minikube service stable-grafana -n monitoring` | admin / prom-operator |
| ArgoCD | `minikube service argocd-server -n argocd` | admin / see Step 16 |
| Local Registry | http://localhost:5001/v2/_catalog | — |
