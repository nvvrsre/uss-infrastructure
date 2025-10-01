#!/bin/bash
# deleteapps.sh
set -euo pipefail

# ==============================
# Run from repo root regardless of where it's invoked
# ==============================
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$BASE_DIR"

# ============ CONFIG ============
# Toggle to also delete PVCs/PVs created by these apps (DANGEROUS: data loss)
NUKE_PVCS="${NUKE_PVCS:-false}"  # set to "true" to wipe PVCs as well

# ============ HELPERS ============
exists_ns() { kubectl get ns "$1" >/dev/null 2>&1; }
exists_release() { helm status "$1" -n "$2" >/dev/null 2>&1; }
kdel() { kubectl delete "$@" --ignore-not-found; } # kubectl delete w/ ignore-not-found

echo "🧹 Starting EKS cleanup..."

# --- 0) Argo CD Apps (delete first so they don't recreate things) ---
if [ -d "${BASE_DIR}/argocd/argocd-apps" ]; then
  echo "👉 Deleting Argo CD app manifests (${BASE_DIR}/argocd/argocd-apps/)..."
  kubectl delete -f "${BASE_DIR}/argocd/argocd-apps/" --ignore-not-found || true
else
  echo "ℹ️  Skipping ${BASE_DIR}/argocd/argocd-apps/ (directory not found)"
fi

# --- 1) Argo CD ---
echo "👉 Deleting Argo CD ingress (if applied)"
kdel -f "${BASE_DIR}/argocd/argocd-ingress.yaml"

if exists_release "argocd" "argocd"; then
  echo "👉 Uninstalling Helm release: argocd (ns: argocd)"
  helm uninstall argocd -n argocd || true
else
  echo "ℹ️  Helm release argocd not found (ns: argocd)"
fi

if exists_ns "argocd"; then
  echo "👉 Deleting namespace: argocd"
  kdel ns argocd
fi

# --- 2) Prometheus + Grafana (kube-prometheus-stack) ---
echo "👉 Deleting Grafana ingress (if applied)"
kdel -f "${BASE_DIR}/monitoring/grafana-ingress.yaml"

if exists_release "monitoring" "monitoring"; then
  echo "👉 Uninstalling Helm release: monitoring (ns: monitoring)"
  helm uninstall monitoring -n monitoring || true
else
  echo "ℹ️  Helm release monitoring not found (ns: monitoring)"
fi

if [ "${NUKE_PVCS}" = "true" ] && exists_ns "monitoring"; then
  echo "⚠️  Deleting PVCs in monitoring (data loss)"
  kubectl delete pvc --all -n monitoring --ignore-not-found || true
fi

if exists_ns "monitoring"; then
  echo "👉 Deleting namespace: monitoring"
  kdel ns monitoring
fi

# --- 3) NGINX Ingress Controller ---
if exists_release "nginx-ingress" "ingress-nginx"; then
  echo "👉 Uninstalling Helm release: nginx-ingress (ns: ingress-nginx)"
  helm uninstall nginx-ingress -n ingress-nginx || true
else
  echo "ℹ️  Helm release nginx-ingress not found (ns: ingress-nginx)"
fi

if exists_ns "ingress-nginx"; then
  echo "👉 Deleting namespace: ingress-nginx"
  kdel ns ingress-nginx
fi

# --- 4) SonarQube + app ingresses in default ---
echo "👉 Deleting app ingresses (if applied)"
kdel -f "${BASE_DIR}/nginx-ingress/ushasree-ingress.yaml"
kdel -f "${BASE_DIR}/sonarqube/sonarqube-ingress.yaml"

if exists_release "sonarqube" "default"; then
  echo "👉 Uninstalling Helm release: sonarqube (ns: default)"
  helm uninstall sonarqube -n default || true
else
  echo "ℹ️  Helm release sonarqube not found (ns: default)"
fi

if [ "${NUKE_PVCS}" = "true" ]; then
  echo "⚠️  Deleting SonarQube PVCs in default (data loss)"
  kubectl delete pvc -n default -l app.kubernetes.io/instance=sonarqube --ignore-not-found || true
fi

# --- 5) cert-manager + ClusterIssuer/Certificates ---
echo "👉 Deleting ClusterIssuer (if applied)"
kdel -f "${BASE_DIR}/nginx-ingress/cluster-issuer.yaml"

echo "👉 Deleting cert-manager core components (v1.15.0 URL used in deploy)"
kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.0/cert-manager.yaml --ignore-not-found || true

echo "👉 Ensuring cert-manager CRDs are deleted"
kdel crd certificaterequests.cert-manager.io \
           certificates.cert-manager.io \
           challenges.acme.cert-manager.io \
           clusterissuers.cert-manager.io \
           issuers.cert-manager.io \
           orders.acme.cert-manager.io

if exists_ns "cert-manager"; then
  echo "👉 Deleting namespace: cert-manager"
  kdel ns cert-manager
fi

# --- 6) Certificates in all namespaces (if any remain) ---
echo "👉 Deleting any remaining Certificate objects cluster-wide"
for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
  kubectl delete certificate --all -n "$ns" --ignore-not-found || true
done

# --- 7) Optional: revert default StorageClass annotation (NO-OP by default) ---
# echo "👉 (Optional) Unset gp2 as default StorageClass"
# kubectl patch storageclass gp2 -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}' || true

echo "✅ Cleanup complete."

if [ "${NUKE_PVCS}" != "true" ]; then
  cat <<'NOTE'
ℹ️  Note:
- PersistentVolumeClaims were NOT deleted. If you want to wipe data (Grafana/Prometheus/SonarQube),
  re-run with: NUKE_PVCS=true ./deleteapps.sh
  This will delete PVCs (and allow dynamic PV cleanup if your provisioner supports it).
NOTE
fi
