# Prometheus Custom Alert Rules Not Showing? RuleSelector and Label Matching Explained

---

## 🛑 Problem: My custom PrometheusRule isn't visible in Prometheus UI

### **Symptoms:**

- You create a `PrometheusRule` (custom alert rules), apply it successfully, but:
  - It **shows up in **``
  - It **does NOT show up in Prometheus UI** under `/alerts` or Grafana alerting
  - Alerts do NOT fire, ever

### **Root Cause: Label Selector Mismatch**

- Your Prometheus Operator (via kube-prometheus-stack) **only loads PrometheusRule objects with matching labels**.
- This is controlled by the `ruleSelector` field in the Prometheus CR (Custom Resource).

---

## 🔍 How RuleSelector Works

**Example Prometheus CR (Helm install):**

```yaml
spec:
  ruleSelector:
    matchLabels:
      release: monitoring
```

This means: *Only PrometheusRule resources in this namespace, with the label **`release: monitoring`**, will be loaded!*

**If your PrometheusRule does NOT have that label, it will be ignored.**

---

## ❌ Example: Wrong Label

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: custom-alerts
  namespace: monitoring
  labels:
    release: prometheus      # <-- WRONG if Prometheus expects "monitoring"
spec:
  groups: ...
```

- This rule will NOT be picked up by Prometheus if the Prometheus CR expects `release: monitoring`.

---

## ✅ Example: Correct Label

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: custom-alerts
  namespace: monitoring
  labels:
    release: monitoring      # <-- CORRECT!  matches the Prometheus ruleSelector
spec:
  groups: ...
```

- This rule WILL be loaded, and alerts will appear in Prometheus UI/Grafana/etc.

---

## 🔥 How to Fix (Step-by-Step)

1. **Find your Prometheus CR's ruleSelector:**
   ```bash
   kubectl get prometheus -n monitoring -o yaml | grep -A5 ruleSelector
   ```
   Example output:
   ```yaml
   ruleSelector:
     matchLabels:
       release: monitoring
   ```
2. **Edit your PrometheusRule YAML:**
   - Under `metadata.labels`, add the *exact* key and value from the `ruleSelector`.
   Example:
   ```yaml
   metadata:
     labels:
       release: monitoring
   ```
3. **Re-apply your rule:**
   ```bash
   kubectl apply -f your-alerts.yaml
   ```
4. **Restart Prometheus (optional, usually not needed):** Prometheus Operator should reload the rule, but if you don't see it after a few minutes:
   ```bash
   kubectl delete pod -l app.kubernetes.io/name=prometheus -n monitoring
   ```

---

## 📝 Table: Match Matrix

| Prometheus CR ruleSelector | PrometheusRule label needed | Will it be loaded? |
| -------------------------- | --------------------------- | ------------------ |
| `release: monitoring`      | `release: monitoring`       | ✅ YES              |
| `release: prometheus`      | `release: prometheus`       | ✅ YES              |
| `release: monitoring`      | `release: prometheus`       | ❌ NO               |

---

## 🧑‍💻 Mentor's Tip

- Always check the expected label by looking at your Prometheus CRD's `ruleSelector`.
- Copy-paste the label key+value *exactly*.
- For default kube-prometheus-stack, label is usually the Helm `release` name (e.g., `monitoring`, `prometheus`, etc.)

---

## 🚩 In summary:

- If custom alert rules aren't firing or showing up, **label mismatch is the #1 cause**.
- **Labels on your PrometheusRule must match the ruleSelector in Prometheus CR.**

---

