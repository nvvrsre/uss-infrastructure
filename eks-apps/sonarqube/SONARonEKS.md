
## **What is OIDC?**

**OIDC (OpenID Connect)** is an authentication protocol based on OAuth 2.0 that lets AWS IAM trust external identity providers, like Kubernetes service accounts in EKS. When you enable OIDC for your EKS cluster, AWS creates a unique OIDC endpoint for your cluster. This allows you to securely grant AWS IAM permissions to specific Kubernetes service accounts, so that only the right pods can access AWS resources (for example, to create and manage EBS volumes).

**Why do we need OIDC in EKS?**

- It enables secure, short-lived, pod-level AWS credentials without hardcoding AWS keys or using broad node IAM roles.
- It is a foundational requirement for using IRSA (IAM Roles for Service Accounts).
- Without OIDC, Kubernetes service accounts cannot assume AWS IAM roles directly, so pods cannot get fine-grained AWS permissions.

**If you skip OIDC:** You cannot use IRSA, and all pods will either lack AWS permissions or must share node-level permissions (which is insecure and not recommended).

---

## **What is IRSA?**

**IRSA (IAM Roles for Service Accounts)** is an AWS EKS feature that allows you to assign IAM roles to Kubernetes service accounts. This means specific pods get only the AWS permissions they need—no more, no less.

**How is IRSA useful?**

- It implements least-privilege access: only the pods running with the right service account can use the attached IAM role.
- No need to use static AWS credentials or assign broad permissions to EC2 worker nodes.
- It improves security and auditability by scoping AWS access to the pod level.

**Why do we need IRSA in this guide?**

- The EBS CSI driver must be able to create, attach, and detach EBS volumes on demand. With IRSA, only the driver pods get this capability—not the whole cluster.
- It’s the AWS-recommended best practice for all pod-to-AWS access in EKS.

**If you skip IRSA:**

- Your pods (like the EBS CSI driver) cannot access the AWS APIs they need, breaking features like dynamic storage provisioning.
- Or, you are forced to use node IAM roles, which means all pods on a node share the same, often overly-permissive AWS permissions—this is less secure and harder to audit.

---

---

## **0. Prerequisites**

- **kubectl**, **eksctl**, and **helm** installed on your machine
- AWS CLI configured and logged in
- Permissions to manage EKS, IAM, CloudFormation, and ELB in your AWS account

---

## **1. Clean Up Old Resources (If Reinstalling)**

```sh
eksctl delete addon --name aws-ebs-csi-driver --cluster ushasreestores-eks --region ap-south-1
kubectl delete serviceaccount ebs-csi-controller-sa -n kube-system
eksctl delete iamserviceaccount --name ebs-csi-controller-sa --namespace kube-system --cluster ushasreestores-eks --region ap-south-1
helm uninstall aws-ebs-csi-driver -n kube-system || true
```

**Why?**\
Removes previous add-ons, service accounts, and roles that can cause “already exists” errors.\
**What if skipped?**\
Your installation may fail with duplicate resource errors.

---

## **2. Ensure Default StorageClass (EBS)**

```sh
kubectl get storageclass
# If gp2/gp3 not (default):
kubectl patch storageclass gp2 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

**Why?**\
Dynamic Persistent Volume Claims (PVCs) use the default StorageClass—ensures SonarQube’s volumes are automatically provisioned using EBS.\
**What if skipped?**\
PVCs may stay in “Pending” state and pods may not start.

---

## **3. Enable OIDC Provider for EKS**

```sh
eksctl utils associate-iam-oidc-provider --region=ap-south-1 --cluster=ushasreestores-eks --approve
```

**Why?**\
Allows Kubernetes service accounts to assume AWS IAM roles securely (required for IRSA).\
**What if skipped?**\
Pods can’t get AWS permissions—EBS volumes won’t mount.

---

## **4. Install EBS CSI Driver as EKS Add-on**

```sh
eksctl create addon --name aws-ebs-csi-driver --cluster ushasreestores-eks --region ap-south-1

sleep 150

**Why?**\
The EBS CSI driver is needed for dynamic EBS storage provisioning in Kubernetes.\
**What if skipped?**\
SonarQube PVCs will never get EBS volumes attached.

---

## **5. Create IAM Role & K8s Service Account for EBS CSI (IRSA)**

```sh
eksctl create iamserviceaccount \
  --name ebs-csi-controller-sa \
  --namespace kube-system \
  --cluster ushasreestores-eks \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --approve
```
sleep 200

**Why?**\
Grants only the EBS CSI driver pods permission to manage EBS volumes using AWS best security practices (least privilege).\
**What if skipped?**\
EBS CSI driver cannot attach/detach volumes, breaking storage for your cluster.

---

## **6. Assign IAM Role to EBS CSI Add-on (AWS Console)**

1. Go to **EKS Console > Clusters > [your cluster] > Add-ons > aws-ebs-csi-driver**
2. Click **Edit/Add IAM Role**
3. Select the new IAM Role from step 5
4. Save

**Why?**\
Links the IAM role to the EBS CSI driver so it can use AWS permissions.\
**What if skipped?**\
EBS CSI driver may still lack necessary AWS permissions—PVCs can’t attach storage.

---

## **7. Validate EBS CSI Driver & Service Account**

```sh
kubectl get pods -n kube-system | grep ebs-csi
kubectl get serviceaccount ebs-csi-controller-sa -n kube-system -o yaml
```

- All EBS CSI pods must be **Running**
- Service account must show `eks.amazonaws.com/role-arn` annotation

**Why?**\
Ensures everything is correctly set up before deploying SonarQube.\
**What if skipped?**\
You might not notice a failed driver/service account until much later, causing harder-to-debug errors.

---

## **8. Prepare SonarQube Helm Values**

Create a `values.yaml` file:

```yaml
monitoringPasscode: "Sonarqube123"
community:
  enabled: true
postgresql:
  enabled: true
service:
  type: ClusterIp
```

**Why?**\
Customizes SonarQube install:

- `monitoringPasscode`—used for monitoring setup
- Enables built-in PostgreSQL for quick start
- Exposes SonarQube using a LoadBalancer for browser access\
  **What if skipped?**\
  Defaults might not suit your environment, and you may not get a public endpoint.

---

## **9. Install SonarQube with Helm**

```sh
helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube
helm repo update
helm install sonarqube sonarqube/sonarqube -n default -f values.yaml
```

**Why?**\
Deploys SonarQube in Kubernetes, configured for AWS EBS and external access.\
**What if skipped?**\
No SonarQube to use!

---

## **10. Validate SonarQube Deployment**

```sh
kubectl get pvc
kubectl get pods
kubectl get svc sonarqube-sonarqube
```

- **PVCs:** must be **Bound** (means EBS storage is attached)
- **Pods:** must be **Running**
- **Service:** must show an **EXTERNAL-IP**

**Why?**\
Confirms SonarQube is healthy and accessible before you try to open the UI.\
**What if skipped?**\
You might try to connect to a broken or inaccessible instance.

---

## **11. Access SonarQube UI**

```sh
kubectl get svc sonarqube-sonarqube
```

- Note the **EXTERNAL-IP**
- Open `http://<EXTERNAL-IP>:9000` in your browser

**Why?**\
Connect to SonarQube UI over the internet via AWS LoadBalancer.

---

## **12. (Production Only) Use External RDS Postgres & Ingress**

- Modify `values.yaml` to configure JDBC connection to an RDS Postgres instance
- Use Kubernetes secrets for passwords
- Set up Ingress for custom DNS/SSL

**Why?**\
Provides better performance, HA, and secure external access in production.

---

## **Troubleshooting Tips**

- PVC stuck? `kubectl describe pvc <name>`
- Pod failing? `kubectl logs <pod-name>`
- No EXTERNAL-IP? Subnet might not be public or ELB IAM permissions missing
- Never install EBS CSI driver with both add-on **and** Helm—pick one

---

## **Summary Table**

| Step                | Why?                                      | What if Skipped?                           |
| ------------------- | ----------------------------------------- | ------------------------------------------ |
| Clean Up            | No “already exists” errors                | Install will fail or be unreliable         |
| StorageClass        | Enables dynamic EBS provisioning          | Pods/PVCs won’t get storage                |
| OIDC Provider       | Allows IRSA for security                  | Driver cannot assume AWS roles             |
| EBS CSI Add-on      | Manages EBS storage for PVCs              | No persistent storage for workloads        |
| IRSA for EBS CSI    | Securely grants permissions to CSI driver | Driver cannot attach/detach volumes        |
| Assign IAM Role     | Connects IAM permissions to the add-on    | Storage driver will not function correctly |
| Validate Setup      | Catch misconfig early                     | Hard-to-debug errors later                 |
| Helm values.yaml    | Customizes install, sets LoadBalancer     | No external access or wrong config         |
| Helm Install        | Deploys SonarQube                         | SonarQube isn’t running                    |
| Validate Deployment | Confirm all components are healthy        | Won’t know about failures                  |
| Access UI           | Connect to SonarQube                      | Can’t use SonarQube                        |

---

# **Save & Reuse: Foolproof SonarQube on EKS Guide**

You can use these steps for any **fresh EKS cluster**—just update the cluster name and region as needed!

------

## sqa_18a9ed87c5fef85c4a86ec9a8bf3b28e9ab030a2