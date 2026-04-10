# DNS and External Access Research Questions for Agent-Based SNO/Compact Clusters

## Context
We are deploying OpenShift SNO and compact 3-node clusters as VirtualMachines on OpenShift Virtualization using RHACM Agent-based installation. The clusters are configured with:
- Base domain: `cluster-xxxj2.dynamic.redhatworkshops.io`
- Cluster name: `sno-test1`
- Expected API: `api.sno-test1.cluster-xxxj2.dynamic.redhatworkshops.io`
- Expected Apps: `*.apps.sno-test1.cluster-xxxj2.dynamic.redhatworkshops.io`
- Cluster VIP: `10.0.2.2` (internal to VM network)

**Problem**: Workshop users need to access these clusters from external networks without control over external DNS infrastructure (no AWS Route53, no corporate DNS admin access). Hub cluster has wildcard DNS: `*.apps.cluster-xxxj2.dynamic.redhatworkshops.io`

**Current Status**:
- ✅ Installation completes successfully with `dns-wildcard-not-configured` validation disabled
- ✅ Cluster is running (100% complete)
- ❌ DNS resolution fails from hub cluster pods for `api.sno-test1.cluster-xxxj2.dynamic.redhatworkshops.io`
- ❌ CoreDNS ConfigMap changes get reverted (operator-managed)
- ❌ OpenShift Routes can't handle API port 6443 (only 80/443)

---

## Research Question 1: CoreDNS Custom Configuration

**Question**: How do you properly configure custom DNS rewrites in OpenShift CoreDNS that persist through DNS Operator reconciliation?

**Details Needed**:
- What is the correct API/resource to use for adding custom DNS entries to CoreDNS in OpenShift 4.x?
- Is there a DNS Operator configuration field for custom forwarding zones or rewrites?
- Can we use ConfigMap overlays or additional CoreDNS ConfigMaps that won't be reverted?
- Are there examples of production OpenShift deployments with custom internal DNS resolution for nested/hosted clusters?

**Related Documentation**:
- OpenShift DNS Operator configuration reference
- CoreDNS plugin configuration in OpenShift
- Custom DNS forwarding zones

---

## Research Question 2: Post-Installation Ingress Domain Reconfiguration

**Question**: Can an Agent-based installed OpenShift cluster's ingress and OAuth domains be reconfigured post-installation to use a different base domain than what was specified during installation?

**Details Needed**:
- Is it possible to change the cluster's ingress controller domain from `*.apps.sno-test1.cluster-xxxj2.dynamic.redhatworkshops.io` to `*.apps.cluster-xxxj2.dynamic.redhatworkshops.io` after installation?
- What components need to be updated? (IngressController, OAuth, Console, etc.)
- Does the API endpoint domain need to match the ingress domain, or can they differ?
- Are there known procedures or KCS articles for changing cluster domains post-install?
- What are the risks/downsides of domain reconfiguration?

**Related Documentation**:
- Ingress Operator domain configuration
- OAuth server hostname configuration
- Console route customization
- ClusterVersion/ClusterOperator behavior during domain changes

---

## Research Question 3: HyperShift/Nested Wildcard DNS Pattern

**Question**: How does HyperShift/Hosted Control Planes solve external access for guest clusters when the guest cluster's apps domain becomes a nested subdomain (e.g., `*.apps.guest.apps.hub.domain.com`)?

**Details Needed**:
- Does HyperShift configure the guest cluster with the nested subdomain AS its baseDomain during installation, or does it reconfigure post-install?
- How does OAuth handle the domain mismatch between the cluster's expected domain and the actual access domain?
- Can this pattern be applied to Agent-based installations (non-HyperShift)?
- What is the exact process: enabling wildcardPolicy on hub, then what happens during guest cluster creation?

**Related Documentation**:
- HyperShift KubeVirt provider ingress configuration
- HyperShift DNS and routing architecture
- Hosted cluster ingress domain configuration

**Specific Test**:
```bash
# Enable wildcard routes on hub
oc patch ingresscontroller -n openshift-ingress-operator default \
  --type=json -p '[{"op": "add", "path": "/spec/routeAdmission", 
  "value": {"wildcardPolicy": "WildcardsAllowed"}}]'

# Then what? How do we configure the cluster to use nested domains?
```

---

## Research Question 4: HAProxy/LoadBalancer Front-End Pattern

**Question**: For environments without external DNS control, what is the recommended pattern for exposing Agent-based cluster API and ingress endpoints using LoadBalancer services or HAProxy on the hub cluster?

**Details Needed**:
- Can we deploy a LoadBalancer/HAProxy on the hub cluster that proxies to the cluster VIPs?
- How would this work for:
  - API access (port 6443) - requires TCP passthrough
  - Console/Apps access (port 443) - requires SNI routing
  - OAuth redirects - how are these handled?
- What about NodePort services pointing to the cluster VIPs?
- Are there examples of this pattern in production OpenShift deployments?

**Potential Solution Architecture**:
```
External User → Hub Cluster LoadBalancer (NodePort/MetalLB) 
              → TCP/SNI Proxy 
              → Cluster VIP (10.0.2.2) 
              → SNO Cluster
```

**Related Documentation**:
- OpenShift LoadBalancer services on bare metal/virt
- HAProxy SNI routing configuration
- MetalLB for internal services

---

## Research Question 5: DNS Validation Disabled - What Now?

**Question**: When `dns-wildcard-not-configured` validation is disabled on AgentServiceConfig, what is the documented procedure for providing external access to the installed cluster?

**Details Needed**:
- What does Red Hat documentation say happens after installation with disabled DNS validation?
- Is there a post-installation checklist or procedure for DNS configuration?
- What are the minimum DNS records required for basic cluster access?
- Can workshop users access with `/etc/hosts` entries as a workaround? (We want to avoid this, but is it the only option without DNS control?)

**DNS Records That Would Be Needed**:
```
# API access
10.0.2.2  api.sno-test1.cluster-xxxj2.dynamic.redhatworkshops.io

# Apps access (wildcard)
10.0.2.2  console-openshift-console.apps.sno-test1.cluster-xxxj2.dynamic.redhatworkshops.io
10.0.2.2  oauth-openshift.apps.sno-test1.cluster-xxxj2.dynamic.redhatworkshops.io
# ... etc for all apps
```

**Related Documentation**:
- Assisted Installer user-managed networking DNS requirements
- Post-installation external access configuration
- Red Hat KCS articles on SNO/Agent-based DNS setup

---

## Research Question 6: Alternative Installation Approach

**Question**: Is there a way to install the cluster with `apps.cluster-xxxj2.dynamic.redhatworkshops.io` AS the baseDomain (not a subdomain of it) while still using Agent-based installation?

**Details Needed**:
- We encountered wildcard DNS validation error when attempting this
- Is there a different way to structure the installation that avoids the nested wildcard problem?
- Can we use a different `clusterName` that doesn't create a subdomain?
- What if we set:
  - `baseDomain: apps.cluster-xxxj2.dynamic.redhatworkshops.io`
  - `clusterName: sno-test1` 
  - Would this result in `*.apps.sno-test1.apps.cluster-xxxj2.dynamic.redhatworkshops.io`?

**Error We Hit**:
```
DNS wildcard configuration was detected for domain 
*.sno-test1.apps.cluster-xxxj2.dynamic.redhatworkshops.io - 
the installation will not be able to complete while this record exists
```

**Related Documentation**:
- AgentClusterInstall baseDomain and clusterName behavior
- Assisted Installer DNS validation logic
- Wildcard DNS validation disabled options

---

## Research Question 7: External-DNS Operator Feasibility

**Question**: Can the external-dns operator be configured to automatically manage DNS records for Agent-based clusters in a split-DNS scenario (where the hub cluster manages DNS for guest cluster domains)?

**Details Needed**:
- Can external-dns operate without AWS/GCP/Azure provider (e.g., using webhook or custom provider)?
- Can it manage CoreDNS on the hub cluster as a DNS backend?
- Would it automatically create DNS records for guest cluster Services/Routes?
- What would be the configuration for monitoring one cluster (guest) and updating DNS on another (hub)?

**Potential Architecture**:
```
SNO Cluster → external-dns operator → Updates → Hub CoreDNS
              (watching Services)              (via API/webhook)
```

**Related Documentation**:
- external-dns webhook provider
- external-dns CoreDNS provider
- external-dns multi-cluster scenarios

---

## Research Question 8: Workshop-Specific Workarounds

**Question**: For workshop/training environments where cost and time matter more than production-grade DNS, what are acceptable temporary workarounds that don't require `/etc/hosts` on each student machine?

**Details Needed**:
- Can we provide a simple web-based proxy/portal that students access, which handles the DNS/routing internally?
- Can we use kubectl port-forward or oc port-forward as a service for students?
- Is there a lightweight DNS server (like dnsmasq) we can run that students point to for this specific domain?
- What about browser extensions or simple DNS override tools?

**Acceptance Criteria**:
- Workshop students can access cluster console and apps with minimal setup
- No manual `/etc/hosts` editing required
- Solution works from student laptops (potentially behind corporate firewalls)
- Cost-effective (part of the $200-300 workshop budget goal)

---

## Research Question 9: Verification and Testing

**Question**: Once we implement a DNS solution, how do we verify it works correctly from all necessary perspectives?

**Test Cases Needed**:
1. **Internal (Hub Cluster Pod)**: DNS resolution and connectivity to cluster API/apps
2. **External (Workshop User Laptop)**: DNS resolution and connectivity to cluster API/apps
3. **OAuth Flow**: Complete login workflow through console → OAuth redirect → success
4. **oc CLI**: `oc login https://api-sno-test1...` works from external
5. **kubeconfig**: Extracted kubeconfig works from external machines

**Testing Commands**:
```bash
# From hub cluster pod
curl -k https://api.sno-test1.cluster-xxxj2.dynamic.redhatworkshops.io:6443
curl -k https://console-openshift-console.apps.sno-test1.cluster-xxxj2.dynamic.redhatworkshops.io

# From external
nslookup api.sno-test1.cluster-xxxj2.dynamic.redhatworkshops.io
curl -k https://api.sno-test1.cluster-xxxj2.dynamic.redhatworkshops.io:6443
oc login --server=https://api.sno-test1.cluster-xxxj2.dynamic.redhatworkshops.io:6443
```

---

## Summary of Current Attempts and Results

| Approach | Status | Issue |
|----------|--------|-------|
| CoreDNS rewrite rules | ❌ Failed | ConfigMap is operator-managed, changes reverted |
| Routes with hub wildcard DNS | ⚠️ Partial | DNS works but port 6443 not supported by Routes |
| Disable DNS validation | ✅ Success | Installation completes but no external access |
| Change cluster baseDomain | ❌ Failed | Wildcard DNS validation error |

---

## Expected Outputs from Research

For each research question, please provide:
1. **Definitive answer** (if available)
2. **Documentation links** (official Red Hat docs, KCS articles, GitHub issues)
3. **Working examples** (commands, YAML manifests, configuration)
4. **Gotchas/Limitations** (known issues, unsupported scenarios)
5. **Recommendation** (should we pursue this approach or not)

The goal is to identify the **correct, supported approach** for providing external access to Agent-based OpenShift clusters deployed as VMs when external DNS infrastructure is not available.
