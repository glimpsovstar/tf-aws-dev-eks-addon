# EKS Architecture Overview

## High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                    AWS Account                                           │
│                                                                                          │
│  ┌────────────────────────────────────────────────────────────────────────────────────┐ │
│  │                                    VPC (10.1.0.0/16)                               │ │
│  │                                                                                     │ │
│  │  ┌─────────────────────────┐    ┌─────────────────────────┐                       │ │
│  │  │   Public Subnets (x3)   │    │  Private Subnets (x3)   │                       │ │
│  │  │  ┌──────────────────┐   │    │  ┌──────────────────┐   │                       │ │
│  │  │  │ NGINX Ingress LB │◄──┼────┼──┤   Worker Nodes    │   │                       │ │
│  │  │  │  (NLB/ALB)       │   │    │  │   EC2 Instances  │   │                       │ │
│  │  │  └──────────────────┘   │    │  │  ┌────────────┐   │   │                       │ │
│  │  │         ▲               │    │  │  │ Node 1     │   │   │                       │ │
│  │  └─────────┼───────────────┘    │  │  │ t3.medium  │   │   │                       │ │
│  │            │                     │  │  └────────────┘   │   │                       │ │
│  │            │                     │  │  ┌────────────┐   │   │   ┌─────────────┐   │ │
│  │  ┌─────────▼───────────┐        │  │  │ Node 2     │   │   │   │ EKS Control │   │ │
│  │  │   Route53 DNS       │        │  │  │ t3.medium  │   │   │   │   Plane     │   │ │
│  │  │ *.david-joo.sbx... │        │  │  └────────────┘   │   │   │  (Managed)  │   │ │
│  │  └─────────────────────┘        │  └──────────────────┘   │   └─────────────┘   │ │
│  │                                  └──────────────────────────┘                      │ │
│  └────────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                          │
│ ┌────────────────────────────────────────────────────────────────────────────────────┐  │
│ │                          Kubernetes Components (Inside EKS)                         │  │
│ │                                                                                     │  │
│ │  ┌─────────────────────────────────────────────────────────────────────────────┐  │  │
│ │  │                              Namespaces                                      │  │  │
│ │  │                                                                              │  │  │
│ │  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │  │  │
│ │  │  │   default    │  │ cert-manager │  │    demo      │  │ kube-system  │  │  │  │
│ │  │  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘  │  │  │
│ │  └─────────────────────────────────────────────────────────────────────────────┘  │  │
│ │                                                                                     │  │
│ │  ┌─────────────────────────────────────────────────────────────────────────────┐  │  │
│ │  │                           Core Services & Addons                             │  │  │
│ │  │                                                                              │  │  │
│ │  │  ┌────────────────────────┐      ┌────────────────────────┐                │  │  │
│ │  │  │   NGINX Ingress        │      │    cert-manager        │                │  │  │
│ │  │  │   Controller           │      │  ┌─────────────────┐   │                │  │  │
│ │  │  │  ┌──────────────┐     │      │  │  Controller     │   │                │  │  │
│ │  │  │  │ Ingress Rules│     │      │  │  Webhook        │   │                │  │  │
│ │  │  │  │ *.domain.com │     │      │  │  CaInjector     │   │                │  │  │
│ │  │  │  └──────────────┘     │      │  └─────────────────┘   │                │  │  │
│ │  │  └────────────────────────┘      └────────────────────────┘                │  │  │
│ │  │                                                                              │  │  │
│ │  │  ┌────────────────────────┐      ┌────────────────────────┐                │  │  │
│ │  │  │   Cluster Autoscaler   │      │    Metrics Server      │                │  │  │
│ │  │  │  (Scales Nodes)        │      │   (CPU/Memory stats)   │                │  │  │
│ │  │  └────────────────────────┘      └────────────────────────┘                │  │  │
│ │  │                                                                              │  │  │
│ │  │  ┌────────────────────────┐      ┌────────────────────────┐                │  │  │
│ │  │  │     CoreDNS            │      │    AWS LB Controller   │                │  │  │
│ │  │  │  (Internal DNS)        │      │   (Manages ALB/NLB)    │                │  │  │
│ │  │  └────────────────────────┘      └────────────────────────┘                │  │  │
│ │  └─────────────────────────────────────────────────────────────────────────────┘  │  │
│ │                                                                                     │  │
│ │  ┌─────────────────────────────────────────────────────────────────────────────┐  │  │
│ │  │                              Applications                                    │  │  │
│ │  │                                                                              │  │  │
│ │  │  ┌────────────────────────────────────────────────────────────────────┐    │  │  │
│ │  │  │                        nginx-demo (demo namespace)                  │    │  │  │
│ │  │  │                                                                     │    │  │  │
│ │  │  │   Ingress ──► Service ──► Deployment ──► Pods (2 replicas)        │    │  │  │
│ │  │  │      ▲           ▲            ▲             ▲                      │    │  │  │
│ │  │  │      │           │            │             │                      │    │  │  │
│ │  │  │  TLS Cert    ClusterIP       HPA      ConfigMaps                  │    │  │  │
│ │  │  │  (Vault)                  (autoscale)  (HTML/Config)              │    │  │  │
│ │  │  └────────────────────────────────────────────────────────────────────┘    │  │  │
│ │  └─────────────────────────────────────────────────────────────────────────────┘  │  │
│ │                                                                                     │  │
│ │  ┌─────────────────────────────────────────────────────────────────────────────┐  │  │
│ │  │                         Kubernetes Resources                                 │  │  │
│ │  │                                                                              │  │  │
│ │  │  • ClusterIssuer (vault-issuer) ────────────────┐                          │  │  │
│ │  │  • ServiceAccounts (cert-manager, etc)          │                          │  │  │
│ │  │  • ClusterRoles & RoleBindings                  │                          │  │  │
│ │  │  • ConfigMaps & Secrets                         │                          │  │  │
│ │  │  • HorizontalPodAutoscaler                      ▼                          │  │  │
│ │  └──────────────────────────────────────────────────────────────────────────┘  │  │
│ └────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                       │
│ ┌────────────────────────────────────────────────────────────────────────────────┐  │
│ │                         External Integrations                                   │  │
│ │                                                                                 │  │
│ │   ┌──────────────────┐        ┌──────────────────┐       ┌──────────────────┐ │  │
│ │   │  HashiCorp Vault │        │  Terraform Cloud │       │     Route53      │ │  │
│ │   │   (HCP Vault)    │◄───────┤   (Workspaces)   │       │   (DNS Zones)    │ │  │
│ │   │                  │        │                   │       │                  │ │  │
│ │   │  • PKI Engine    │        │ • tf-aws-dev-eks │       │ • A/CNAME Records│ │  │
│ │   │  • K8s Auth      │        │ • tf-aws-dev-    │       │                  │ │  │
│ │   │  • Policies      │        │   eks-addon      │       └──────────────────┘ │  │
│ │   └──────────────────┘        └──────────────────┘                            │  │
│ └────────────────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────────────────┘
```

## Traffic Flow

### nginx-demo Application Traffic Flow
```
User ──► Route53 ──► NLB ──► NGINX Ingress ──► Service ──► Pod
                              Controller        (ClusterIP)  (nginx-demo)
                                   │
                                   ├── TLS Termination (Vault Cert)
                                   └── HTTP Routing Rules
```

### Certificate Flow
```
cert-manager ──► vault-issuer ──► Vault PKI ──► Issue Cert ──► Secret ──► Ingress
     │               │              (HCP)                        │           │
     │               │                                          │           │
     └── Watch ──────┴── K8s Auth ─────────────────────────────┘           │
         Ingress         (JWT Token)                                       │
         Annotations                                                        │
                                                                           │
                                                            TLS Termination ◄┘
```

## cert-manager and Vault Integration Architecture

### Detailed Integration Flow

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              Kubernetes Cluster (EKS)                                │
│                                                                                      │
│  ┌────────────────────────────────────────────────────────────────────────────────┐ │
│  │                          cert-manager Namespace                                │ │
│  │                                                                                │ │
│  │  ┌──────────────────────┐      ┌──────────────────────┐                      │ │
│  │  │  cert-manager         │      │  cert-manager        │                      │ │
│  │  │  Controller           │      │  Webhook             │                      │ │
│  │  │                       │      │                      │                      │ │
│  │  │  Watches:             │      │  Validates:         │                      │ │
│  │  │  • Ingresses          │      │  • Certificates     │                      │ │
│  │  │  • Certificates       │      │  • Issuers          │                      │ │
│  │  │  • Secrets            │      └──────────────────────┘                      │ │
│  │  └──────────┬────────────┘                                                    │ │
│  │             │                                                                  │ │
│  └─────────────┼──────────────────────────────────────────────────────────────────┘ │
│                │                                                                      │
│  ┌─────────────▼──────────────────────────────────────────────────────────────────┐ │
│  │                         Certificate Lifecycle Process                           │ │
│  │                                                                                │ │
│  │  1. Ingress Created                2. Certificate Request                     │ │
│  │  ┌─────────────────┐              ┌─────────────────┐                        │ │
│  │  │ apiVersion:     │              │ apiVersion:     │                        │ │
│  │  │   networking/v1 │              │   cert-manager/ │                        │ │
│  │  │ kind: Ingress   │  triggers    │   v1            │                        │ │
│  │  │ annotations:    │──────────────►│ kind:          │                        │ │
│  │  │   cert-manager. │              │   Certificate   │                        │ │
│  │  │   io/cluster-   │              │ spec:           │                        │ │
│  │  │   issuer:       │              │   issuerRef:    │                        │ │
│  │  │   vault-issuer  │              │   vault-issuer  │                        │ │
│  │  └─────────────────┘              └────────┬────────┘                        │ │
│  │                                            │                                  │ │
│  │                                            ▼                                  │ │
│  │  5. Secret Created                 3. ClusterIssuer                          │ │
│  │  ┌─────────────────┐              ┌─────────────────┐                        │ │
│  │  │ kind: Secret    │              │ apiVersion:     │                        │ │
│  │  │ type:           │◄─────────────│   cert-manager/ │                        │ │
│  │  │   kubernetes.io/│   stores     │   v1            │                        │ │
│  │  │   tls           │   cert       │ kind:           │                        │ │
│  │  │ data:           │              │   ClusterIssuer │                        │ │
│  │  │   tls.crt: ...  │              │ metadata:       │                        │ │
│  │  │   tls.key: ...  │              │   name:         │                        │ │
│  │  │   ca.crt: ...   │              │   vault-issuer  │                        │ │
│  │  └─────────────────┘              └────────┬────────┘                        │ │
│  │         ▲                                   │                                 │ │
│  │         │                                   │ 4. Authentication              │ │
│  └─────────┼───────────────────────────────────┼─────────────────────────────────┘ │
│            │                                   │                                     │
│  ┌─────────┴───────────────────────────────────▼─────────────────────────────────┐ │
│  │                     Vault Authentication & Authorization                       │ │
│  │                                                                                │ │
│  │  ┌────────────────────────────────────────────────────────────────────────┐  │ │
│  │  │                     Kubernetes Auth Method Flow                         │  │ │
│  │  │                                                                         │  │ │
│  │  │  1. ServiceAccount JWT Token Request                                   │  │ │
│  │  │     cert-manager SA ──► TokenRequest API ──► JWT with audience         │  │ │
│  │  │                                                                         │  │ │
│  │  │  2. JWT Validation                                                     │  │ │
│  │  │     JWT ──► Kubernetes API ──► Validate SA ──► Return Claims          │  │ │
│  │  │                                                                         │  │ │
│  │  │  3. Vault Token Issue                                                  │  │ │
│  │  │     Valid JWT ──► Vault Auth ──► Issue Token with Policies            │  │ │
│  │  └────────────────────────────────────────────────────────────────────────┘  │ │
│  └────────────────────────────────────────────────────────────────────────────────┘ │
│                                        │                                             │
└────────────────────────────────────────┼─────────────────────────────────────────────┘
                                         │
                                         ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                          HashiCorp Vault (HCP)                                       │
│                                                                                      │
│  ┌────────────────────────────────────────────────────────────────────────────────┐ │
│  │                              Namespace: admin                                  │ │
│  │                                                                                │ │
│  │  ┌──────────────────┐      ┌──────────────────────┐      ┌─────────────────┐ │ │
│  │  │  Kubernetes Auth │      │    PKI Engine        │      │   Policies      │ │ │
│  │  │  Path: auth/     │      │    Path: pki-demo/   │      │                 │ │ │
│  │  │  kubernetes/     │      │                      │      │ cert-manager-   │ │ │
│  │  │                  │      │  ┌────────────────┐  │      │ policy:         │ │ │
│  │  │  Role:           │─────►│  │  Root CA       │  │◄─────│ • pki-demo/sign │ │ │
│  │  │  cert-manager    │      │  │  Certificate   │  │      │ • pki-demo/issue│ │ │
│  │  │                  │      │  └────────────────┘  │      │ • pki-demo/roles│ │ │
│  │  │  Bound to:       │      │                      │      └─────────────────┘ │ │
│  │  │  • SA: cert-     │      │  ┌────────────────┐  │                          │ │
│  │  │    manager       │      │  │  Role:         │  │                          │ │
│  │  │  • NS: cert-     │      │  │  kubernetes    │  │                          │ │
│  │  │    manager       │      │  │                │  │                          │ │
│  │  │  • Audience:     │      │  │  Allows:       │  │                          │ │
│  │  │    vault URL     │      │  │  • *.domain    │  │                          │ │
│  │  └──────────────────┘      │  │  • TTL: 72h    │  │                          │ │
│  │                             │  └────────────────┘  │                          │ │
│  │                             └──────────────────────┘                          │ │
│  └────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                      │
│                          Certificate Issuance Result                                 │
│                          ┌────────────────────────┐                                 │
│                          │  X.509 Certificate     │                                 │
│                          │  • CN: nginx-demo...   │                                 │
│                          │  • CA: Demo Root CA    │                                 │
│                          │  • Valid: 72 hours     │                                 │
│                          │  • Auto-renew: 50m     │                                 │
│                          └────────────────────────┘                                 │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### Key Integration Points

1. **No Sidecars Required**: cert-manager handles everything as a cluster-wide controller
2. **Automatic Certificate Lifecycle**:
   - Creation: Triggered by Ingress annotations
   - Renewal: Automatic before expiry (renewBefore: 50m)
   - Storage: As native Kubernetes Secrets
   - Revocation: On resource deletion

3. **Security Flow**:
   - cert-manager ServiceAccount creates JWT token with Vault URL as audience
   - Vault validates JWT against Kubernetes API
   - Vault issues short-lived token with cert-manager-policy
   - cert-manager uses token to request certificate from PKI engine
   - Certificate stored as Kubernetes Secret
   - Ingress controller uses Secret for TLS termination

### Why This Architecture is Superior to Alternatives

| Approach | Pros | Cons | Use Case |
|----------|------|------|----------|
| **cert-manager + Vault** (Our Choice) | • Native K8s integration<br>• Automatic renewal<br>• No sidecars<br>• Standard pattern | • Only for certificates | TLS/SSL certificates |
| **Vault Secrets Operator** | • Handles any secret type<br>• Direct Vault sync | • Additional operator<br>• More complex for just certs | General secrets management |
| **Vault Agent Sidecar** | • Works with any app<br>• Template rendering | • Resource overhead<br>• One sidecar per pod<br>• Complex lifecycle | Legacy applications |
| **Manual Management** | • Full control | • Error-prone<br>• No automation<br>• Operational burden | Not recommended |

## Components Description

### Infrastructure Layer
- **VPC**: 10.1.0.0/16 network with public and private subnets across 3 AZs
- **EKS Control Plane**: AWS-managed Kubernetes API server and etcd
- **Worker Nodes**: EC2 instances (t3.medium) in private subnets
- **Load Balancer**: Network Load Balancer in public subnets for ingress

### Kubernetes Core Services
- **NGINX Ingress Controller**: Handles external traffic routing and TLS termination
- **cert-manager**: Automates certificate lifecycle management
- **Cluster Autoscaler**: Automatically scales EC2 nodes based on pod requirements
- **Metrics Server**: Provides resource metrics for HPA
- **CoreDNS**: Internal cluster DNS resolution
- **AWS Load Balancer Controller**: Manages AWS ALB/NLB resources

### Application Layer
- **nginx-demo**: Demo application showcasing Vault PKI integration
  - Deployment with 2 replicas
  - ClusterIP Service
  - Ingress with TLS from Vault
  - HorizontalPodAutoscaler for auto-scaling
  - ConfigMaps for HTML content and nginx configuration

### External Integrations
- **HashiCorp Vault (HCP)**: Provides PKI engine for certificate management
- **Terraform Cloud**: Infrastructure automation and state management
- **Route53**: DNS management for external access

## Key Features

1. **Automated Certificate Management**: cert-manager integrates with Vault PKI for automatic certificate issuance and renewal
2. **Auto-scaling**: Both pod-level (HPA) and node-level (Cluster Autoscaler) scaling
3. **High Availability**: Multi-AZ deployment with redundant components
4. **Secure by Default**: Private nodes, TLS everywhere, Vault-managed certificates
5. **GitOps Ready**: All infrastructure defined as code in Terraform

## Access Patterns

All applications follow the same pattern:
1. DNS resolution via Route53
2. Traffic enters through shared NGINX Ingress Controller
3. TLS termination at ingress level (using Vault-issued certificates)
4. HTTP traffic forwarded to backend services
5. Services route to appropriate pods

This unified approach simplifies operations and reduces infrastructure costs by sharing a single load balancer across all applications.