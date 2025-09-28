helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install monitoring prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace -f values.yaml
kubectl get pods -n monitoring
kubectl get svc -n monitoring
kubectl apply -f grafana-ingress.yaml
kubectl apply -f prometheus-ingress.yaml
kubectl get secret --namespace monitoring monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo