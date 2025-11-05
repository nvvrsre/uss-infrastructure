# 🚀 NGINX Ingress Controller with HTTPS on AWS EKS – Full Guide

---

## 1. **What is the NGINX Ingress Controller?**

- A Kubernetes-native way to expose your cluster services to the outside world.
- It acts as a reverse proxy, routing incoming HTTP/HTTPS requests to backend services based on rules.
- NGINX is the most popular open-source controller, supported and production-proven.

---

## 2. **Why Use Ingress on EKS?**

- **Centralizes** routing logic, HTTPS termination, and URL-based routing for all workloads.
- **Enables production security:** Easily integrate Let’s Encrypt for free, automated SSL/TLS.
- **Supports** path, subdomain, and host-based routing (microservices, monoliths, everything).

---

## 3. **Prerequisites**

- EKS cluster (already running)
- `kubectl`, `helm`, and basic AWS IAM permissions (for EKS and Route53/DNS updates)
- Your DNS (e.g. `www.ushasree.com`) **must point to the Ingress Controller ELB** for HTTPS to work

---

## 4. **Step-by-Step Installation**

### **A. Add and Update Helm Repository**

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
```

---

### **B. Install the NGINX Ingress Controller**

```bash
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace
```

- Creates controller pods and a Service of type **LoadBalancer** (AWS ELB).

---

### **C. Check Controller Deployment and Get ELB Address**

```bash
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

Look for the `nginx-ingress-ingress-nginx-controller` service.

- **EXTERNAL-IP** is your AWS ELB (e.g. `a1b2c3d4e5f6g7.elb.amazonaws.com`)

---

### **D. Update Your DNS**

- In your DNS provider, set a **CNAME** record for your domain (e.g., `www.ushasree.com`) pointing to the above ELB hostname.
- **Wait for DNS to propagate (can take a few minutes).**

---

### **E. Install cert-manager (for Let’s Encrypt TLS Certificates)**

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.0/cert-manager.yaml
```

Wait until all pods in `cert-manager` namespace are **Running**:

```bash
kubectl get pods -n cert-manager
```

---

### **F. Create a ClusterIssuer for Let’s Encrypt**

Create a file called `cluster-issuer.yaml`:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: nushasree25@gmail.com              # <--- Change to your email!
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

Apply:

```bash
kubectl apply -f cluster-issuer.yaml
```

---

### **G. Create Your Ingress Resource (with HTTPS)**

**Example for multiple services (**``**, **``**, **``**):**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ushasree-ingress
  namespace: default
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - www.ushasree.com
      secretName: ushasree-tls
  rules:
    - host: www.ushasree.com
      http:
        paths:
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: api-gateway
                port:
                  number: 80
          - path: /products
            pathType: Prefix
            backend:
              service:
                name: product-service
                port:
                  number: 3002
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend
                port:
                  number: 80
```

**Apply:**

```bash
kubectl apply -f ushasree-ingress.yaml
```

---

### **H. Check Certificate Issuance**

```bash
kubectl get certificate -A
```

- You should see `ushasree-tls` with `READY=True` in a few minutes if DNS is correct.

---

### **I. Access Your Application Over HTTPS**

- Visit: `https://www.ushasree.com`
- You should see a valid certificate (padlock) and your frontend (or service) response.

---

## 5. **Troubleshooting & Tips**

- **Certificate stuck/not issuing:**

  - Check DNS is pointing to the ELB
  - Run: `kubectl describe certificate ushasree-tls -n default` for errors
  - Cert-manager must be running and healthy

- **No EXTERNAL-IP on service:**

  - EKS nodes must have IAM permissions for ELB
  - Subnets must be tagged for ELB
  - Wait 2–10 min after install

- **404 or backend errors:**

  - Make sure all referenced services (`api-gateway`, `product-service`, `frontend`) exist and are running

---

## 6. **How Does It Work?**

- **Ingress Controller** listens for incoming traffic at your ELB and routes requests to services based on Ingress rules.
- **cert-manager** automates SSL certificate issuance and renewal with Let’s Encrypt.
- **HTTPS is automatic**—valid, browser-trusted certificates for your app.

---

## 7. **Cleanup (if needed)**

```bash
helm uninstall nginx-ingress -n ingress-nginx
kubectl delete namespace ingress-nginx
kubectl delete -f letsencrypt-prod.yaml
kubectl delete -f ushasree-ingress.yaml
kubectl delete namespace cert-manager
```

---

## 8. **References**

- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [cert-manager Docs](https://cert-manager.io/docs/)
- [AWS EKS Ingress Guide](https://docs.aws.amazon.com/eks/latest/userguide/ingress.html)

---

**Ready for prod-ready HTTPS and easy routing!**\
**If you want help with custom domains, multi-host, or advanced TLS, just ask.**

