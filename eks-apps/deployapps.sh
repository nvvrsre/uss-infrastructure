#!/bin/bash
set -euo pipefail

# Run from repo root regardless of where it's invoked
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$BASE_DIR"

# ===== Helpers =====
wait_rollout() {
  local ns="$1" dep="$2" timeout="${3:-180s}"
  echo "⏳ Waiting for rollout: deploy/${dep} (ns: ${ns})..."
  kubectl -n "${ns}" rollout status "deploy/${dep}" --timeout="${timeout}"
}

wait_endpoints() {
  local ns="$1" svc="$2" timeout="${3:-120}"  # seconds
  echo "⏳ Waiting for endpoints on Service/${svc} in ${ns} (up to ${timeout}s)..."
  local i=0
  while [[ $i -lt $timeout ]]; do
    local count
    count="$(kubectl -n "${ns}" get endpoints "${svc}" -o jsonpath='{.subsets[0].addresses[*]}' 2>/dev/null | wc -w | tr -d ' ')"
    if [[ "${count:-0}" -gt 0 ]]; then
      echo "✅ Endpoints ready for ${svc} (${count})"
      return 0
    fi
    sleep 2
    i=$((i+2))
  done
  echo "❌ Timed out waiting for endpoints on ${svc}"
  return 1
}

apply_with_retry() {
  local file="$1" attempts="${2:-5}" sleep_s="${3:-6}"
  local n=1
  until kubectl apply -f "${file}"; do
    if [[ $n -ge $attempts ]]; then
      echo "❌ Failed to apply ${file} after ${attempts} attempts."
      return 1
    fi
    echo "⚠️  Apply of ${file} failed (attempt ${n}/${attempts}). Retrying in ${sleep_s}s..."
    sleep "${sleep_s}"
    n=$((n+1))
  done
  echo "✅ Applied ${file}"
}

# ==============================
# Deploy Apps in EKS
# ==============================

echo "👉 Setting default StorageClass..."
# NOTE: many EKS clusters now default to gp3. Keep gp2 if that's what you created.
kubectl patch storageclass gp2 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}' || true
kubectl get storageclass

# ==============================
# Install SonarQube
# ==============================
echo "👉 Installing SonarQube..."
helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube
helm repo update
helm upgrade --install sonarqube sonarqube/sonarqube \
  -n default \
  -f "${BASE_DIR}/sonarqube/sonarqubevalues.yaml"

# ==============================
# Install NGINX Ingress Controller
# ==============================
echo "👉 Installing NGINX Ingress..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace

# ==============================
# Install Cert-Manager (with waits)
# ==============================
echo "👉 Installing Cert-Manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.0/cert-manager.yaml

# Wait for cert-manager components to be Ready before using the webhook
wait_rollout cert-manager cert-manager
wait_rollout cert-manager cert-manager-cainjector
wait_rollout cert-manager cert-manager-webhook

# Ensure the webhook Service has endpoints
kubectl -n cert-manager get svc cert-manager-webhook
wait_endpoints cert-manager cert-manager-webhook 180

echo "👉 Applying ClusterIssuer (with retry)..."
# You have two similar files in the tree; using the one under nginx-ingress/
apply_with_retry "${BASE_DIR}/nginx-ingress/cluster-issuer.yaml" 6 8

# ==============================
# Apply Ingress Rules
# ==============================
echo "👉 Applying Ingress manifests..."
apply_with_retry "${BASE_DIR}/nginx-ingress/ushasree-ingress.yaml"
apply_with_retry "${BASE_DIR}/sonarqube/sonarqube-ingress.yaml"

# ==============================
# Install Prometheus + Grafana
# ==============================
echo "👉 Installing Prometheus Stack..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  -f "${BASE_DIR}/monitoring/prometheusvalues.yaml"

echo "👉 Applying Grafana Ingress..."
apply_with_retry "${BASE_DIR}/monitoring/grafana-ingress.yaml"

# ==============================
# Install ArgoCD
# ==============================
echo "👉 Installing ArgoCD..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm upgrade --install argocd argo/argo-cd --namespace argocd --create-namespace

# ArgoCD ingress + apps
apply_with_retry "${BASE_DIR}/argocd/argocd-ingress.yaml"
kubectl apply -f "${BASE_DIR}/argocd/argocd-apps/"

# ==============================
# Check Certificates
# ==============================
echo "👉 Checking Certificates..."
kubectl get certificate -A || true


kubectl get svc -A | grep LoadBalancer || true

echo "Copy the above LoadBalancer IPs and create DNS A records for the required domains."

sleep 100

echo "👉 Recreating Ingress manifests to ensure final state..."
# Delete then re-apply (only the files that exist in the new layout)
kubectl delete -f "${BASE_DIR}/nginx-ingress/ushasree-ingress.yaml" || true
kubectl delete -f "${BASE_DIR}/sonarqube/sonarqube-ingress.yaml" || true
kubectl delete -f "${BASE_DIR}/monitoring/grafana-ingress.yaml" || true
kubectl delete -f "${BASE_DIR}/argocd/argocd-ingress.yaml" || true

apply_with_retry "${BASE_DIR}/nginx-ingress/ushasree-ingress.yaml"
apply_with_retry "${BASE_DIR}/sonarqube/sonarqube-ingress.yaml"
apply_with_retry "${BASE_DIR}/monitoring/grafana-ingress.yaml"
apply_with_retry "${BASE_DIR}/argocd/argocd-ingress.yaml"


# ==============================
# Get ArgoCD Initial Admin Password
# ==============================
echo "👉 Getting ArgoCD Initial Admin Password..."
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

sleep 400
echo "👉 Final Certificate Check..."
kubectl get certificate -A

echo "✅ Deployment completed successfully! Now you can access the installed applications via their respective domains."

echo "✅✅✅✅✅ Ushasree Stores has been developed by Ushasree Technologies(N Vishnuvardhan & Mentor(ChatGPT))"