# Why Alertmanager Notifications Did Not Work (and How We Fixed It)

## Situation: No Notifications Despite Firing Alerts

You had a working Kubernetes cluster with kube-prometheus-stack, Alertmanager, and firing alerts in Prometheus, but **no notifications** (Slack/email) were being received—even for `severity: critical` alerts.

---

## Root Cause: **Alertmanager Was Not Loading Your Custom Config**

- You manually created a Secret called `alertmanager-main` with your Alertmanager configuration.
- However, your Alertmanager pod was actually mounting a different Secret: `alertmanager-monitoring-kube-prometheus-alertmanager-generated` (created and managed by the Prometheus Operator/Helm chart).
- As a result, the live Alertmanager config inside the pod was just a default dummy config (with only a `null` receiver). **No real notification endpoints were configured!**
- So, even though your config existed, it was never used by Alertmanager. This is why you saw alerts firing in Prometheus/Alertmanager UI, but received no Slack or email messages.

---

## How We Identified the Issue

1. **Checked Alertmanager’s Loaded Config**

   - Used:
     ```bash
     kubectl exec -n monitoring <alertmanager-pod> -- cat /etc/alertmanager/config_out/alertmanager.env.yaml
     ```
   - Saw a config with only `null` receiver (no Slack or email settings).

2. **Inspected StatefulSet Volumes**

   - Found that Alertmanager’s pod actually loads its config from a generated secret managed by the Operator, not your `alertmanager-main` secret.

3. **Compared to Custom Secret**

   - Confirmed your custom config was present in the cluster—but not mounted in the pod.

---

## Solution: **Manage Alertmanager Config via Helm values.yaml**

- For `kube-prometheus-stack` (Helm), you must configure Alertmanager in your `values.yaml` under the `alertmanager.config` key.
- Example snippet to add/edit in your `values.yaml`:

```yaml
alertmanager:
  config:
    global:
      smtp_smarthost: 'smtp.gmail.com:587'
      smtp_from: 'nushasree25@gmail.com'
      smtp_auth_username: 'nushasree25@gmail.com'
      smtp_auth_password: '<your-app-password>'
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
          - to: 'nvvr53@gmail.com'
            send_resolved: true
      - name: 'slack-notifications'
        slack_configs:
          - api_url: '<your-slack-webhook-url>'
            channel: '#alerts'
            send_resolved: true
```

- Apply changes with:
  ```bash
  helm upgrade monitoring prometheus-community/kube-prometheus-stack -n monitoring -f values.yaml
  ```
- This will update the **correct secret** (`alertmanager-monitoring-kube-prometheus-alertmanager-generated`), and Alertmanager will reload the correct config.

---

## How To Check Your Fix

1. **Verify Loaded Config in Pod:**
   ```bash
   kubectl exec -n monitoring <alertmanager-pod> -- cat /etc/alertmanager/config_out/alertmanager.env.yaml
   ```
   - Should show your Slack and email configs.
2. **Trigger a Test Alert:**
   - Confirm you receive notifications in Slack and email when a `severity: critical` alert fires.

---

## Key Lessons

- Always check which secret or config file Alertmanager is actually using (inspect the pod and its mounts).
- For Helm/kube-prometheus-stack, always manage Alertmanager config via `values.yaml` and **not** by manually creating secrets.
- After config changes, upgrade via Helm and confirm the config is live in the pod.
- Use `kubectl exec ... cat ...` to inspect configs actually loaded by pods.

---

## References

- [kube-prometheus-stack Helm Chart Docs](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Prometheus Alertmanager Docs](https://prometheus.io/docs/alerting/latest/alertmanager/)
- [Helm Upgrade Command](https://helm.sh/docs/helm/helm_upgrade/)

