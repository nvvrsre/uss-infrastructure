#!/bin/bash

# === CONFIGURE THESE VARIABLES ===
CLUSTER_NAME="nvvr-eks"                  # Your EKS cluster name
REGION="ap-south-1"                      # Your AWS region
VPC_ID="vpc-0dfa8c47164dc04ac"           # Your VPC ID
POLICY_NAME="AWSLoadBalancerControllerIAMPolicy"
ROLE_NAME="AmazonEKSLoadBalancerControllerRole"

# === 1. Create IAM Policy for Controller ===
echo "Creating IAM policy..."
curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.1/docs/install/iam_policy.json

aws iam create-policy \
  --policy-name $POLICY_NAME \
  --policy-document file://iam-policy.json || echo "Policy may already exist."

POLICY_ARN="arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/$POLICY_NAME"

# === 2. Enable OIDC Provider for EKS ===
echo "Enabling OIDC provider for EKS..."
eksctl utils associate-iam-oidc-provider --region $REGION --cluster $CLUSTER_NAME --approve

# === 3. Get OIDC provider URL ===
OIDC_URL=$(aws eks describe-cluster --name $CLUSTER_NAME --query "cluster.identity.oidc.issuer" --output text | sed 's~https://~~')

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# === 4. Create Trust Policy JSON ===
cat > trust-policy.json <<EOL
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::$ACCOUNT_ID:oidc-provider/$OIDC_URL"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "$OIDC_URL:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }
  ]
}
EOL

# === 5. Create the IAM Role ===
echo "Creating IAM Role..."
aws iam create-role \
  --role-name $ROLE_NAME \
  --assume-role-policy-document file://trust-policy.json || echo "Role may already exist."

# === 6. Attach the Policy to the Role ===
echo "Attaching IAM policy to role..."
aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn $POLICY_ARN

ROLE_ARN="arn:aws:iam::$ACCOUNT_ID:role/$ROLE_NAME"

# === 7. Create Kubernetes Service Account YAML ===
cat > aws-load-balancer-controller-sa.yaml <<EOL
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: $ROLE_ARN
EOL

# === 8. Apply Service Account ===
echo "Applying Kubernetes service account..."
kubectl apply -f aws-load-balancer-controller-sa.yaml

# === 9. Install AWS Load Balancer Controller via Helm ===
echo "Installing AWS Load Balancer Controller with Helm..."
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=$REGION \
  --set vpcId=$VPC_ID

# === 10. Verify Installation ===
echo "Installation complete! Checking pods:"
kubectl get pods -n kube-system | grep aws-load

echo "Script completed. Check above for pod status. If you see pods running, your controller is installed!"
