eksctl delete addon --name aws-ebs-csi-driver --cluster ushasreestores-eks --region ap-south-1
kubectl delete serviceaccount ebs-csi-controller-sa -n kube-system
eksctl delete iamserviceaccount --name ebs-csi-controller-sa --namespace kube-system --cluster ushasreestores-eks --region ap-south-1
helm uninstall aws-ebs-csi-driver -n kube-system || true

kubectl get storageclass
# If gp2/gp3 not (default):
kubectl patch storageclass gp2 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

eksctl utils associate-iam-oidc-provider --region=ap-south-1 --cluster=ushasreestores-eks --approve

eksctl create addon --name aws-ebs-csi-driver --cluster ushasreestores-eks --region ap-south-1


eksctl create iamserviceaccount \
  --name ebs-csi-controller-sa \
  --namespace kube-system \
  --cluster ushasreestores-eks \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --approve

echo "Please update IAM role for EKS to allow EBS CSI driver access."


helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube
helm repo update
helm install sonarqube sonarqube/sonarqube -n default -f values.yaml


kubectl get pods -n kube-system | grep ebs-csi
kubectl get serviceaccount ebs-csi-controller-sa -n kube-system -o yaml
kubectl get pvc
kubectl get pods
kubectl get svc sonarqube-sonarqube