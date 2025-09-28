helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace
echo "Wait for the NGINX Ingress Controller to be ready"
sleep 60
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.0/cert-manager.yaml
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
kubectl get pods -n cert-manager
sleep 60
kubectl apply -f cluster-issuer.yaml
kubectl apply -f ushasree-ingress.yaml

