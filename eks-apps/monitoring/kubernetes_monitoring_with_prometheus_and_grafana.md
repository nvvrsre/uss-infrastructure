# 📊 Prometheus & Grafana for Kubernetes: Deep-Dive, Interview-Ready Notes (kube-prometheus-stack Edition)

---

## 1. **What is Prometheus?**

**Prometheus** is the leading open-source monitoring system for cloud-native infrastructure.

- **Time-series database:** Stores metrics as timestamped series, with key-value labels (e.g., `pod`, `namespace`, `job`).
- **Pull-based metrics:** Scrapes `/metrics` endpoints at intervals, rather than pushing.
- **PromQL:** Flexible query language for metrics analytics and alerting.
- **Alerting:** Rules for system and application health, integrated with Alertmanager.
- **Cloud native:** Supports dynamic discovery (Kubernetes, EC2, etc.).

### **Why Prometheus?**

- **Observability:** See what’s happening inside your apps and infrastructure.
- **Self-service:** Easy for devs and SREs to add new metrics.
- **Alerting:** Proactive, not reactive, ops.
- **Open Standard:** Supported by Kubernetes and most modern workloads.

---

## 2. **Prometheus Stack Architecture (with kube-prometheus-stack)**

The **kube-prometheus-stack** Helm chart is the industry best practice for production Kubernetes monitoring.\
It includes:

- **Prometheus Operator:** Manages Prometheus, Alertmanager, and Grafana using Kubernetes-native CRDs.
- **Prometheus:** Scrapes metrics and runs alert rules.
- **Alertmanager:** Handles routing of alerts (Slack, email, etc.).
- **Grafana:** Visualizes metrics from Prometheus.
- **Exporters:** Pre-configured exporters such as node-exporter (nodes), kube-state-metrics (K8s objects), etc.
- **Custom Resources (CRDs):**
  - **ServiceMonitor:** Declaratively tells Prometheus what services to scrape.
  - **PodMonitor:** Same, but for pod-level endpoints.
  - **PrometheusRule:** Define custom alert rules (PromQL-based) for Prometheus.
  - **(Optional) Thanos, Blackbox, etc.**

**[Diagram: Typical kube-prometheus-stack on EKS]**

```
      +-----------------------+
      |      Grafana          |
      +----------+------------+
                 |
      +----------v------------+
      |     Prometheus        |<---[Alert Rules: PrometheusRule CRD]
      +----+------+-----------+
           |      ^
           |      |
+----------v--+ +--v----------+
| Exporters   | |ServiceMonitor|<---K8s Services
| Node/KubeSM | |PodMonitor    |<---K8s Pods
+-------------+ +--------------+
           |
      +----v------------+
      |  Alertmanager   |--> Slack, Email, etc.
      +-----------------+
```

---

## 3. **What is Grafana?**

**Grafana** is an open-source dashboard and analytics platform:

- **Dashboards:** Interactive visualizations of Prometheus (and other) metrics.
- **Panels:** Graphs, tables, heatmaps, logs.
- **Multi-data source:** Prometheus, Loki, InfluxDB, MySQL, etc.
- **Alerting:** Alerts on visual thresholds and trends.
- **Collaboration:** Share dashboards, templating, versioning.

---

## 4. **How Prometheus & Grafana Work Together**

- **Prometheus:** Collects and serves metrics from apps/exporters.
- **Grafana:** Connects to Prometheus as a data source; dashboards built with PromQL queries.
- **Typical workflow:**\
  Apps/exporters → `/metrics` → Prometheus → Grafana dashboards/alerts.

---

## 5. **Step-by-Step: Install Prometheus & Grafana on Kubernetes (with kube-prometheus-stack)**

### **Step 1: Prerequisites**

- Kubernetes cluster up and running
- `kubectl` and `helm` installed/configured

### **Step 2: Add Helm Repository**

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

### **Step 3: Install kube-prometheus-stack (Recommended!)**

```bash
helm install monitoring prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace
```
helm upgrade monitoring prometheus-community/kube-prometheus-stack -n monitoring -f values.yaml


- This deploys the **full monitoring stack**: Prometheus, Grafana, Alertmanager, exporters, CRDs.

### **Step 4: Verify Everything is Running**

```bash
kubectl get pods -n monitoring
kubectl get svc -n monitoring
```

- Make sure all pods are `Running` and services (`grafana`, `kube-prometheus-prometheus`, etc.) exist.

### **Step 5: Access Prometheus and Grafana (for Dev/Testing)**

**Prometheus:**

```bash
kubectl port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090 -n monitoring
# Browse http://localhost:9090
```

**Grafana:**

```bash
kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring
# Browse http://localhost:3000
```

**Grafana Login:**

- User: `admin`
- Password:
  ```bash
  kubectl get secret --namespace monitoring monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
  ```

### **Step 6: Expose Prometheus & Grafana Publicly (Production)**

**Recommended: Use Ingress + HTTPS (with cert-manager/nginx).**

**Sample Ingress for Grafana:**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-ingress
  namespace: monitoring
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - grafana.ushasree.xyz
      secretName: grafana-tls
  rules:
    - host: grafana.ushasree.xyz
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: monitoring-grafana
                port:
                  number: 80
```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: prometheus-ingress
  namespace: monitoring
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - prometheus.ushasree.xyz
      secretName: prometheus-tls
  rules:
    - host: prometheus.ushasree.xyz
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: monitoring-kube-prometheus-prometheus
                port:
                  number: 9090



**Apply:**

```bash
kubectl apply -f grafana-ingress.yaml
```

- Point DNS to your Ingress controller’s public IP/hostname.

---


## 6. **Dashboards and Alerts: Best Practices**

### **Import Community Dashboards**

- Login to Grafana > Import popular dashboards from [grafana.com/dashboards](https://grafana.com/grafana/dashboards/).
- Kubernetes dashboards: **315**, **10000**, **6417**, etc.

---

## 7. **Interview Concepts & PromQL: Must-Know**

### **Sample PromQL Queries**

- **CPU usage by namespace:**
  ```promql
  sum(rate(container_cpu_usage_seconds_total{image!=""}[5m])) by (namespace)
  ```
- **Memory usage by pod:**
  ```promql
  sum(container_memory_usage_bytes{image!=""}) by (pod)
  ```
- **Pod restarts in last 10 minutes:**
  ```promql
  increase(kube_pod_container_status_restarts_total[10m])
  ```

### **CRDs in Prometheus Operator**

- **ServiceMonitor:** Define what K8s Services to scrape.
- **PodMonitor:** For pod-level metric endpoints.
- **PrometheusRule:** Custom alerting rules.

---

## 8. **Best Practices for Enterprise Clusters**

- **Persistent storage** for Prometheus and Grafana (avoid data loss).
- **Restrict public access** with HTTPS and authentication (OAuth2, SSO, etc.).
- **Tune data retention** (`prometheus.prometheusSpec.retention` in Helm values).
- **Use labels/annotations** in PrometheusRule for easier filtering/routing.
- **Integrate Alertmanager** with Slack, PagerDuty, etc.
- **Regular backups** for dashboards and Prometheus data.
- **Leverage community dashboards and rules**—don’t reinvent the wheel!

---

## 9. **Useful References**

- [Prometheus Docs](https://prometheus.io/docs/)
- [kube-prometheus-stack Helm Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Grafana Docs](https://grafana.com/docs/)
- [Prometheus Operator CRDs](https://github.com/prometheus-operator/prometheus-operator)
- [Awesome Prometheus Alerts](https://awesome-prometheus-alerts.grep.to/)

---
# 🚨 Prometheus Alert Rules, Descriptions, and Notification Guide

## 1. Production-Ready PrometheusRule Example

Paste the following YAML into `cluster-combined-alerts.yaml` and apply with:

```bash
kubectl apply -f cluster-combined-alerts.yaml
```

---

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: cluster-combined-alerts
  namespace: monitoring
  labels:
    app.kubernetes.io/instance: prometheus
    app: prometheus
    release: prometheus
spec:
  groups:
    - name: node.rules
      rules:
        - alert: NodeDown
          expr: up{job="node-exporter"} == 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Node is down (instance {{ $labels.instance }})"
            description: "Node has been unreachable for 5m."
            runbook_url: "https://runbooks.prometheus-operator.dev/runbooks/node/node_down"

        - alert: NodeFilesystemAlmostFull
          expr: 100 - (node_filesystem_avail_bytes{mountpoint="/"} * 100 / node_filesystem_size_bytes{mountpoint="/"}) < 10
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Node filesystem almost full (instance {{ $labels.instance }})"
            description: "Less than 10% disk space left on root filesystem."
            runbook_url: "https://runbooks.prometheus-operator.dev/runbooks/node/node_disk_full"

        - alert: KubeNodeNotReady
          expr: kube_node_status_condition{condition="Ready", status="true"} == 0
          for: 2m
          labels:
            severity: critical
          annotations:
            summary: "Kubernetes node not ready"
            description: "Node {{ $labels.node }} is not Ready for 2m."

        - alert: KubeNodeDiskPressure
          expr: kube_node_status_condition{condition="DiskPressure", status="true"} == 1
          for: 2m
          labels:
            severity: warning
          annotations:
            summary: "Node has disk pressure"
            description: "Node {{ $labels.node }} is under disk pressure."

    - name: pod.rules
      rules:
        - alert: PodCrashLooping
          expr: rate(kube_pod_container_status_restarts_total[5m]) > 0.1
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "Pod is crashlooping frequently (instance {{ $labels.instance }})"
            description: "Pod restart rate is high over the last 10 minutes."

        - alert: PodNotReady
          expr: kube_pod_status_ready{condition="true"} == 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Pod not ready (pod {{ $labels.pod }}, ns {{ $labels.namespace }})"
            description: "Pod has been in NotReady state for 5m."

        - alert: KubePodNotHealthy
          expr: sum by (namespace,pod) (kube_pod_status_phase{phase=~"Pending|Failed|Unknown"}) > 0
          for: 2m
          labels:
            severity: critical
          annotations:
            summary: "Pod not healthy (instance {{ $labels.instance }})"
            description: "Pod {{ $labels.namespace }}/{{ $labels.pod }} is not running for >2m. VALUE={{ $value }} LABELS={{ $labels }}"

        - alert: KubernetesPodCrashLooping
          expr: increase(kube_pod_container_status_restarts_total[2m]) > 3
          for: 2m
          labels:
            severity: warning
          annotations:
            summary: "Pod crash looping (instance {{ $labels.instance }})"
            description: "Pod {{ $labels.namespace }}/{{ $labels.pod }} is crash looping. VALUE={{ $value }} LABELS={{ $labels }}"

        - alert: KubernetesDaemonsetRolloutStuck
          expr: kube_daemonset_status_number_ready / kube_daemonset_status_desired_number_scheduled * 100 < 100
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "DaemonSet rollout stuck"
            description: "Some Pods of DaemonSet {{ $labels.namespace }}/{{ $labels.daemonset }} are not scheduled or not ready. VALUE={{ $value }}"

        - alert: KubernetesContainerOomKiller
          expr: (kube_pod_container_status_restarts_total - kube_pod_container_status_restarts_total offset 10m >= 1) and ignoring (reason) min_over_time(kube_pod_container_status_last_terminated_reason{reason="OOMKilled"}[10m]) == 1
          for: 0m
          labels:
            severity: warning
          annotations:
            summary: "Container OOM Killed"
            description: "Container {{ $labels.container }} in pod {{ $labels.namespace }}/{{ $labels.pod }} was OOMKilled {{ $value }} times in 10m."

        - alert: PodOOMKilled
          expr: increase(kube_pod_container_status_terminated_reason{reason="OOMKilled"}[5m]) > 0
          for: 0m
          labels:
            severity: critical
          annotations:
            summary: "Pod OOMKilled (pod {{ $labels.pod }}, ns {{ $labels.namespace }})"
            description: "Pod was killed due to out of memory."

    - name: resource.rules
      rules:
        - alert: HighPodCPU
          expr: sum(rate(container_cpu_usage_seconds_total{container!="",container!="POD"}[5m])) by (pod,namespace) > 0.8
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "Pod high CPU usage (pod {{ $labels.pod }}, ns {{ $labels.namespace }})"
            description: "Pod CPU usage is over 80% for 10m."

        - alert: HighNodeMemory
          expr: (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) < 0.15
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "Node memory is low (instance {{ $labels.instance }})"
            description: "Node has less than 15% memory available."

        - alert: ContainerHighCpuUtilization
          expr: (sum(rate(container_cpu_usage_seconds_total{container!=""}[5m])) by (pod, container) / sum(container_spec_cpu_quota{container!=""}/container_spec_cpu_period{container!=""}) by (pod, container) * 100) > 80
          for: 2m
          labels:
            severity: warning
          annotations:
            summary: "Container High CPU utilization"
            description: "Container CPU utilization > 80% for 2m. LABELS={{ $labels }}"

        - alert: ContainerHighMemoryUsage
          expr: (sum(container_memory_working_set_bytes{name!!=""}) BY (instance, name) / sum(container_spec_memory_limit_bytes > 0) BY (instance, name) * 100) > 80
          for: 2m
          labels:
            severity: warning
          annotations:
            summary: "Container High Memory usage"
            description: "Container Memory usage > 80%. LABELS={{ $labels }}"

        - alert: KubePersistentVolumeFillingUp
          expr: kubelet_volume_stats_available_bytes / kubelet_volume_stats_capacity_bytes * 100 < 10
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "PersistentVolume almost full"
            description: "Volume on node {{ $labels.instance }} is almost full (<10% left)."

    - name: traffic.rules
      rules:
        - alert: HighErrorRate
          expr: sum(rate(http_requests_total{status=~"5.."}[5m])) by (job) > 0.05
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "High HTTP 5xx error rate (job {{ $labels.job }})"
            description: "More than 0.05 5xx errors/sec for 5 minutes."

        - alert: HighRequestLatency
          expr: histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{handler="/api"}[5m])) by (le,job)) > 0.5
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "High request latency on /api (job {{ $labels.job }})"
            description: "95th percentile request latency > 0.5s over last 10m."

    - name: controlplane.rules
      rules:
        - alert: KubeAPIDown
          expr: absent(up{job="apiserver"})
          for: 1m
          labels:
            severity: critical
          annotations:
            summary: "Kubernetes API server is down"
            description: "No API server targets are up."

        - alert: KubeSchedulerDown
          expr: absent(up{job="kube-scheduler"})
          for: 1m
          labels:
            severity: critical
          annotations:
            summary: "Kubernetes scheduler is down"
            description: "No scheduler targets are up."

        - alert: KubeControllerManagerDown
          expr: absent(up{job="kube-controller-manager"})
          for: 1m
          labels:
            severity: critical
          annotations:
            summary: "Kubernetes controller manager is down"
            description: "No controller manager targets are up."

        - alert: KubeApiServerErrors
          expr: sum(rate(apiserver_request_total{code=~\"5..\"}[5m])) by (instance) > 1
          for: 2m
          labels:
            severity: critical
          annotations:
            summary: "Kubernetes API server errors"
            description: "API server instance {{ $labels.instance }} has error rate > 1/s over 5m."
```

---

## 2. Description & Explanation of Each Alert

### node.rules

- **NodeDown** (Critical): Notifies if a node (via node-exporter) has been down/unreachable for 5 minutes. Indicates major cluster health/risk of outages.
- **NodeFilesystemAlmostFull** (Warning): Node root filesystem has less than 10% free space for 5 minutes. Prevents disk full, which can cause pod/cluster failures.
- **KubeNodeNotReady** (Critical): Node has not reported "Ready" for 2 minutes. Shows node may be cordoned, disconnected, or out of resources.
- **KubeNodeDiskPressure** (Warning): Node reports disk pressure (out of disk I/O, too many pods, etc.) for 2 minutes. Can lead to pod eviction or scheduling issues.

### pod.rules

- **PodCrashLooping** (Warning): Pod container restart rate is high (>0.1 per 5 minutes) for 10 minutes. Often means the pod is stuck/crashing.
- **PodNotReady** (Critical): Pod is not Ready for 5 minutes. May not be serving traffic or is stuck.
- **KubePodNotHealthy** (Critical): Any pod is Pending/Failed/Unknown for more than 2 minutes. Indicates scheduling or crashing problems.
- **KubernetesPodCrashLooping** (Warning): Pod restarts more than 3 times in 2 minutes. Rapid failure.
- **KubernetesDaemonsetRolloutStuck** (Warning): DaemonSet rollout is stuck (not all pods are scheduled or ready) for 10 minutes. Operator action needed.
- **KubernetesContainerOomKiller** (Warning): Container has been OOMKilled (out-of-memory killed) at least once in the last 10 minutes.
- **PodOOMKilled** (Critical): Pod was killed due to out of memory. Strong signal for memory tuning or node sizing.

### resource.rules

- **HighPodCPU** (Warning): Pod's CPU usage >80% for 10 minutes. Useful for performance tuning.
- **HighNodeMemory** (Warning): Node memory free <15% for 10 minutes. Can cause pod eviction or failures.
- **ContainerHighCpuUtilization** (Warning): Container-level CPU >80% for 2 minutes. Indicates CPU-intensive processes.
- **ContainerHighMemoryUsage** (Warning): Container-level memory >80% for 2 minutes. Watch for memory leaks.
- **KubePersistentVolumeFillingUp** (Warning): Persistent Volume has <10% space left for 10 minutes. Prevents disk full for critical workloads.

### traffic.rules

- **HighErrorRate** (Critical): HTTP 5xx error rate >0.05/sec for 5 minutes (per job). Used for detecting API/server errors fast.
- **HighRequestLatency** (Warning): /api endpoint p95 latency >0.5 seconds for 10 minutes. Detects slow backend/service.

### controlplane.rules

- **KubeAPIDown** (Critical): No API server targets are up for 1 minute. Means Kubernetes control plane is unreachable!
- **KubeSchedulerDown** (Critical): Scheduler is down for 1 minute. New pods will not be scheduled.
- **KubeControllerManagerDown** (Critical): Controller-manager is down for 1 minute. Cluster self-healing is broken.
- **KubeApiServerErrors** (Critical): API server has >1 error/sec rate for 2 minutes. Indicates degraded control plane health.

---

## 3. When Will You Get Notifications?

- For **critical** alerts (severity: critical), you get notified when the problem persists for the `for:` duration (e.g., 5m, 2m, 10m).
- For **warning** alerts (severity: warning), you get notified after the specified `for:` period.
- Alerts fire when the condition is true for the full time. Alerts are sent to Alertmanager, which routes to Slack/email/etc.

---

## 4. Sending Alert Notifications to Email & Slack

### A. Create Alertmanager Config Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: alertmanager-main
  namespace: monitoring
labels:
  app: kube-prometheus-stack-alertmanager
type: Opaque
stringData:
  alertmanager.yaml: |
    global:
      smtp_smarthost: 'smtp.gmail.com:587'
      smtp_from: 'your_email@gmail.com'
      smtp_auth_username: 'your_email@gmail.com'
      smtp_auth_password: 'your_app_password'
      smtp_require_tls: true

    route:
      receiver: 'slack-notifications'
      group_wait: 10s
      group_interval: 1m
      repeat_interval: 10m
      routes:
        - receiver: 'email-notifications'
          match:
            severity: critical

    receivers:
      - name: 'email-notifications'
        email_configs:
          - to: 'recipient@email.com'
            send_resolved: true

      - name: 'slack-notifications'
        slack_configs:
          - api_url: 'https://hooks.slack.com/services/XXX/YYY/ZZZ'
            channel: '#alerts'
            send_resolved: true
```

- Update emails, SMTP app password, and Slack webhook/channel.
- For Gmail, you must use an App Password, not your login password.

Apply to your cluster:

```bash
kubectl apply -f alertmanager-config.yaml
```

### B. Reload Alertmanager

```bash
kubectl delete pod -l app.kubernetes.io/name=alertmanager -n monitoring
```

---

## 5. How It Works

- **Prometheus**: Matches rules and triggers alerts
- **Alertmanager**: Receives, deduplicates, and sends to your Slack/email
- **You**: Get notified on Slack and/or email for every alert

---

## 6. Test Alerting

- Force an alert (e.g., cordon a node, fill disk, kill a pod)
- Verify you get Slack/email notifications as expected!

---

*Mentor’s tip: Always test your alerts and notification flow before relying on them in production.*

