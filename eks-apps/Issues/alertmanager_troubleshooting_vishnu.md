# Alertmanager Notification Troubleshooting (EKS/Kube-Prometheus-Stack)

---

## 1. **Symptoms**

- Alerts are **firing in Prometheus** and seen in the Alertmanager UI, **but some should be suppressed (e.g., EKS master/control plane alerts)**.
- **Alertmanager pod fails to start** after config change.
- You see this error in `kubectl describe alertmanager ...`:
    ```
    provision alertmanager configuration: failed to initialize from secret: missing name in receiver
    ```
- Or you notice suppressed alerts are still generating notifications.

---

## 2. **Root Cause**

- In your Helm `values.yaml`, your Alertmanager config included:
    ```yaml
    - name: null
    ```
  instead of the **correct, quoted string**:
    ```yaml
    - name: 'null'
    ```
- Unquoted `null` is interpreted by YAML as a special value, *not* a string.  
- The Prometheus Operator **requires every receiver to have a non-empty string name**—and treats YAML `null` as missing, which is invalid.
- This caused the Operator to **fail to reconcile** your Alertmanager, blocking pod/secret creation and config updates.

---

## 3. **How to Identify**

- Run:
    ```bash
    kubectl describe alertmanager <name> -n <namespace>
    ```
    and look for the message:
    ```
    provision alertmanager configuration: failed to initialize from secret: missing name in receiver
    ```

- Run:
    ```bash
    kubectl get secret alertmanager-<name>-generated -n <namespace>
    ```
    If it’s missing, or if the Alertmanager pod won’t start, config is invalid.

- Decode the secret and confirm if the `"null"` receiver is present:
    ```bash
    kubectl get secret alertmanager-<name>-generated -n <namespace> -o jsonpath="{.data.alertmanager\\.yaml\\.gz}" | base64 -d | gunzip
    ```

---

## 4. **How to Fix**

**Edit your `values.yaml` to ensure all receivers, including the "null" receiver, are defined as strings:**

```yaml
alertmanager:
  config:
    global:
      smtp_smarthost: 'smtp.gmail.com:587'
      smtp_from: 'your@email.com'
      smtp_auth_username: 'your@email.com'
      smtp_auth_password: 'your-app-password'
      smtp_require_tls: true

    route:
      receiver: 'slack-notifications'
      group_wait: 10s
      group_interval: 1m
      repeat_interval: 10m
      routes:
        - receiver: 'null'
          match:
            alertname: KubeControllerManagerDown
        - receiver: 'null'
          match:
            alertname: KubeSchedulerDown
        - receiver: 'null'
          match:
            alertname: Watchdog
        - receiver: 'email-notifications'
          match:
            severity: critical

    receivers:
      - name: 'email-notifications'
        email_configs:
          - to: 'your@email.com'
            send_resolved: true

      - name: 'slack-notifications'
        slack_configs:
          - api_url: '<your-slack-webhook>'
            channel: '#alerts'
            send_resolved: true

      - name: 'null'
```
> **Every receiver name must be quoted.** Never use bare `null`!

**Apply your fix:**
```bash
helm upgrade monitoring prometheus-community/kube-prometheus-stack -n monitoring -f values.yaml
```

---

## 5. **Validate the Fix**

- Confirm the Alertmanager pod and secret are created:
    ```bash
    kubectl get pods -n monitoring
    kubectl get secret -n monitoring | grep alertmanager
    ```
- Decode the running config and confirm `"null"` routes are present:
    ```bash
    kubectl get secret alertmanager-monitoring-kube-prometheus-alertmanager-generated -n monitoring -o jsonpath="{.data.alertmanager\\.yaml\\.gz}" | base64 -d | gunzip
    ```
- Suppressed alerts will not trigger notifications!

---

## 6. **Lessons & Best Practices**

- **Receiver names must always be quoted as strings in YAML (`'null'`, not bare `null`).**
- If Alertmanager or Prometheus Operator can’t reconcile, always check `kubectl describe alertmanager ...` for validation errors.
- Use `kubectl get secret` and decode to check the live config.
- Always restart the Operator if you suspect it’s not reconciling.
- Always apply Helm upgrades from the correct `values.yaml`!

---

## 7. **References**

- [Prometheus Operator Helm Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Alertmanager Config Docs](https://prometheus.io/docs/alerting/latest/alertmanager/)
- [YAML Gotchas](https://yaml.org/spec/1.2/spec.html#id2765878)

---

**You fixed it, Vishnu!  
Your monitoring stack is now enterprise-grade, EKS-aware, and clean.  
Keep this doc for all future Prometheus + Alertmanager troubleshooting.**

