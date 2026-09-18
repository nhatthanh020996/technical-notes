# Kubernetes (K8s) Learning Mind Map

```
Kubernetes (K8s)
│
├── Core Concepts
│   ├── Pods
│   │   ├── Single/multi-container pods
│   │   ├── Pod lifecycle
│   │   ├── Pod security context
│   │   └── Pod resource management
│   │
│   ├── Controllers
│   │   ├── ReplicaSets
│   │   ├── Deployments
│   │   ├── StatefulSets
│   │   ├── DaemonSets
│   │   └── Jobs & CronJobs
│   │
│   ├── Services & Networking
│   │   ├── Service types (ClusterIP, NodePort, LoadBalancer)
│   │   ├── Ingress controllers
│   │   ├── NetworkPolicies
│   │   └── DNS and service discovery
│   │
│   └── Storage
│       ├── Volumes
│       ├── PersistentVolumes
│       ├── PersistentVolumeClaims
│       └── StorageClasses
│
├── Architecture
│   ├── Control Plane Components
│   │   ├── kube-apiserver
│   │   ├── etcd
│   │   ├── kube-scheduler
│   │   └── kube-controller-manager
│   │
│   ├── Node Components
│   │   ├── kubelet
│   │   ├── kube-proxy
│   │   └── Container runtime
│   │
│   ├── Cluster Communication
│   │   ├── Node-to-control-plane
│   │   ├── Control-plane-to-node
│   │   └── API server authentication
│   │
│   └── Addons
│       ├── DNS
│       ├── Dashboard
│       └── Container Resource Monitoring
│
├── Workload Management
│   ├── Scaling
│   │   ├── Manual scaling
│   │   ├── Horizontal Pod Autoscaler
│   │   └── Vertical Pod Autoscaler
│   │
│   ├── Updates & Rollbacks
│   │   ├── Rolling updates
│   │   ├── Canary deployments
│   │   └── Blue/Green deployments
│   │
│   ├── Batch Processing
│   │   ├── Jobs
│   │   └── CronJobs
│   │
│   └── Resource Management
│       ├── Requests & Limits
│       ├── Quality of Service classes
│       └── Resource quotas & LimitRanges
│
├── Configuration
│   ├── ConfigMaps
│   ├── Secrets
│   ├── Environment variables
│   └── Application configuration
│
├── Security
│   ├── Authentication
│   │   ├── Service accounts
│   │   ├── User authentication strategies
│   │   └── OpenID Connect
│   │
│   ├── Authorization
│   │   ├── RBAC (Role-Based Access Control)
│   │   ├── Roles & ClusterRoles
│   │   └── RoleBindings & ClusterRoleBindings
│   │
│   ├── Admission Control
│   │   ├── Admission controllers
│   │   ├── ValidatingWebhooks
│   │   └── MutatingWebhooks
│   │
│   └── Security Contexts & Policies
│       ├── Pod Security Policies
│       ├── Network Policies
│       └── Security Context
│
├── Observability
│   ├── Monitoring
│   │   ├── Metrics
│   │   ├── Prometheus
│   │   └── Grafana
│   │
│   ├── Logging
│   │   ├── Container logs
│   │   ├── Node logs
│   │   └── Centralized logging (EFK/ELK)
│   │
│   └── Tracing & Debugging
│       ├── Distributed tracing
│       ├── Debugging techniques
│       └── kubectl debugging commands
│
├── Advanced Topics
│   ├── Custom Resources & Operators
│   │   ├── Custom Resource Definitions (CRDs)
│   │   ├── Operator pattern
│   │   └── Operator Framework
│   │
│   ├── Multi-cluster Management
│   │   ├── Federation
│   │   ├── Multi-cluster services
│   │   └── Cluster API
│   │
│   ├── Service Mesh
│   │   ├── Istio
│   │   ├── Linkerd
│   │   └── Service mesh concepts
│   │
│   └── GitOps & CI/CD
│       ├── ArgoCD
│       ├── Flux
│       └── GitOps principles
│
└── Administration & Tooling
    ├── Cluster Setup & Management
    │   ├── kubeadm
    │   ├── kops
    │   └── Managed K8s services (EKS, GKE, AKS)
    │
    ├── Package Management
    │   ├── Helm
    │   ├── Kustomize
    │   └── YAML management
    │
    ├── Development Tools
    │   ├── Skaffold
    │   ├── Telepresence
    │   └── kind, minikube, k3s
    │
    └── Disaster Recovery
        ├── Backup strategies
        ├── Restore procedures
        └── High availability patterns
```

This mind map provides a comprehensive overview of Kubernetes concepts, organized from core fundamentals to advanced topics. For learning K8s effectively, I recommend following this path:

1. Start with Core Concepts to understand the basic building blocks
2. Move to Architecture to grasp how the system works
3. Proceed to Workload Management and Configuration
4. Then explore Security aspects
5. Add Observability skills to monitor and troubleshoot
6. Finally explore Advanced Topics and Administration as you become more proficient

This progressive approach helps build a solid foundation before tackling more complex topics. You may want to supplement this learning path with hands-on exercises using tools like Minikube or k3d for local development environments.