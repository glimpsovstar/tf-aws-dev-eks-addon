# EKS Addons Deployment

This workspace deploys:
- NGINX Ingress Controller
- cert-manager

## After Deployment

To create Let's Encrypt ClusterIssuers:

1. **Configure kubectl:**
   ```bash
   aws eks update-kubeconfig --region ap-southeast-2 --name vault-demo-cluster
   ```

2. **Verify cert-manager is running:**
   ```bash
   kubectl get pods -n cert-manager
   ```

3. **Update the email in cluster-issuers.yaml:**
   ```bash
   # Edit cluster-issuers.yaml and replace "your-email@example.com" with your actual email
   ```

4. **Apply the ClusterIssuers:**
   ```bash
   kubectl apply -f cluster-issuers.yaml
   ```

5. **Verify ClusterIssuers are created:**
   ```bash
   kubectl get clusterissuers
   ```

## Using the ClusterIssuers

Once created, you can use the ClusterIssuers in your Ingress resources:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-ingress
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"  # or "letsencrypt-staging"
spec:
  tls:
  - hosts:
    - example.com
    secretName: example-tls
  rules:
  - host: example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: example-service
            port:
              number: 80
```