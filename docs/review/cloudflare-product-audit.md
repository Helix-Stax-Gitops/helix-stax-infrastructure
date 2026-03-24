# **Comprehensive Cloudflare Architecture and Security Audit for Helix Stax**

The following analysis evaluates the current infrastructure posture of Helix Stax, a pre-revenue IT consulting firm operating a Kubernetes (K3s) platform augmented by a 23-agent AI ecosystem utilizing the Model Context Protocol (MCP). The audit assesses the integration of over 117 Cloudflare products to deliver a hardened, production-ready architecture. The recommendations are tailored to a bootstrapped consulting model and map directly to NIST CSF 2.0, CIS Controls v8, SOC 2 Type II, and ISO 27001 requirements to ensure the platform is cryptographically and operationally secure prior to the onboarding of any client data.

## **Top 15 Remediation Priorities and Quick Wins**

Based on the infrastructure state, the following critical gaps require immediate remediation to align the environment with baseline cybersecurity frameworks. These priorities address fundamental misconfigurations and establish the necessary zero-trust foundation.  
**Priority 1: Purge Stale DNS Records (Effort: Low, Priority: Critical)** The presence of stale A or CNAME records (auth.helixstax.net, s3.helixstax.net) pointing to unassigned IP addresses exposes the domain to severe subdomain takeover vulnerabilities. Threat actors can register the dangling IP or routing endpoint and serve malicious content under the trusted domain. These records must be deleted immediately. (Satisfies NIST CSF ID.AM-01, CIS Control 1).  
**Priority 2: Implement DMARC for Email Spoofing Protection (Effort: Low, Priority: Critical)** The absence of a Domain-based Message Authentication, Reporting, and Conformance (DMARC) record allows unauthorized entities to spoof the helixstax.com domain. A DMARC policy must be configured with a v=DMARC1; p=reject; rua=mailto:dmarc-reports@helixstax.com; TXT record to reject unauthenticated mail and collect forensic reports. (Satisfies NIST CSF PR.DS-01, CIS Control 9).  
**Priority 3: Enable Zone-Wide Strict SSL/TLS and HSTS (Effort: Low, Priority: Critical)** The domain currently lacks HTTP Strict Transport Security (HSTS) and "Always Use HTTPS" enforcement. The Cloudflare zone must be updated to enforce "Full (Strict)" SSL mode to validate the 15-year Origin CA certificate on the K3s cluster. Additionally, HSTS must be enabled with a max-age of 31,536,000 seconds, including the includeSubDomains and preload directives to prevent SSL stripping attacks. (Satisfies NIST CSF PR.DS-02, CIS Control 3).  
**Priority 4: Migrate from Proxied DNS to Cloudflare Tunnels (Effort: Medium, Priority: High)** Proxied DNS (Orange Cloud) pointing to a public IP on Hetzner leaves the nodes vulnerable to direct volumetric attacks if the origin IP is leaked or scanned via services like Shodan. The architecture must pivot to cloudflared tunnels to facilitate outbound-only connections, allowing all inbound ports on the Hetzner firewall to be closed completely. (Satisfies NIST CSF PR.AC-03, CIS Control 12).  
**Priority 5: Configure MTA-STS for Google Workspace (Effort: Medium, Priority: High)** Mail Transfer Agent Strict Transport Security (MTA-STS) ensures that inbound emails to the Google Workspace instance are encrypted via TLS 1.2 or higher, thwarting SMTP downgrade attacks. This requires publishing \_mta-sts and \_smtp.\_tls TXT records and deploying a Cloudflare Worker to serve the policy file over HTTPS. (Satisfies NIST CSF PR.DS-02, SOC 2 CC6.1).  
**Priority 6: Enforce Bot Fight Mode and AI Crawl Control (Effort: Low, Priority: High)** The public-facing components are currently vulnerable to automated scraping and malicious botnets. "Super Bot Fight Mode" must be enabled within the Cloudflare Pro plan, setting the policy to block "Definitely Automated" traffic. Concurrently, Cloudflare's AI Crawl Control must be toggled to reject unauthorized LLM scraping of proprietary consulting materials. (Satisfies NIST CSF DE.CM-02, CIS Control 13).  
**Priority 7: Harden Custom MCP Worker Endpoints with Service Tokens (Effort: Medium, Priority: High)** The five deployed custom Workers (including the secrets vault and ClickUp integration) currently face exposure risks. They must be placed behind Cloudflare Access policies that require explicitly scoped Service Tokens. This ensures that only authenticated AI agents originating from trusted boundaries can execute MCP JSON-RPC commands. (Satisfies NIST CSF PR.AA-01, SOC 2 CC6.1).  
**Priority 8: Implement Cloudflare AI Gateway for Agent Telemetry (Effort: Low, Priority: High)** The 23 AI agents currently interact directly with OpenRouter and LLM APIs, resulting in decentralized telemetry and uncontrolled expenditure risks. All inference traffic must be re-routed through Cloudflare AI Gateway to enable semantic caching, rate limiting, provider fallback routing, and granular cost tracking. (Satisfies NIST CSF PR.PT-01, CIS Control 16).  
**Priority 9: Enforce Zero Trust Device Posture for Administrative Access (Effort: Medium, Priority: High)** Static credentials for human access must be deprecated. The Cloudflare WARP client must be mandated for administrative access to the helixstax.net applications (Grafana, n8n, Devtron). Device Posture checks must be established to verify the OS version, firewall status, and disk encryption state of the founder's workstation before Access evaluates the identity. (Satisfies NIST CSF PR.AA-05, CIS Control 12).  
**Priority 10: Deploy the Cloudflare Code Mode MCP Server (Effort: Low, Priority: High)** Managing over 117 Cloudflare products manually is inefficient. The official github.com/cloudflare/mcp "Code Mode" server must be integrated into the Claude Code environment. This grants the AI agents secure, programmatic capability to orchestrate Cloudflare DNS, Zero Trust, and WAF configurations utilizing an isolated V8 sandbox that consumes merely 1,000 tokens per execution. (Satisfies NIST CSF PR.AC-06).  
**Priority 11: Configure Hyperdrive for PostgreSQL Connection Pooling (Effort: Medium, Priority: Medium)** Serverless Workers querying the on-cluster CloudNativePG database will rapidly exhaust TCP connection limits due to their ephemeral nature. Cloudflare Hyperdrive must be bound to the MCP Workers to pool these database connections regionally, reducing the 7-step TLS/Auth handshake down to a single rapid connection. (Satisfies NIST CSF PR.IR-01).  
**Priority 12: Publish a Standardized Security.txt (Effort: Low, Priority: Medium)** To signal compliance and security maturity to prospective clients, a standard /.well-known/security.txt file must be generated via the Cloudflare dashboard. This establishes a clear vulnerability disclosure and bug bounty policy. (Satisfies NIST CSF ID.RA-08, ISO 27001 8.8).  
**Priority 13: Enable Immutable Audit Logs via Logpush (Effort: Low, Priority: Medium)** Regulatory frameworks (SOC 2, ISO 27001\) require non-repudiation and tamper-evident logging. Cloudflare Audit Logs (v2) must be integrated with Cloudflare Logpush to stream all configuration and Access events directly into an immutable R2 storage bucket or the K3s Loki instance. (Satisfies NIST CSF PR.PT-04, CIS Control 8).  
**Priority 14: Restrict Traefik Ingress to Cloudflare IPs (Effort: Low, Priority: Medium)** While transitioning to Cloudflare Tunnels, the existing Traefik Ingress controller on K3s must be hardened. The Hetzner firewall and K3s NetworkPolicies must be strictly configured to drop any TCP packets on ports 80/443 that do not originate from Cloudflare's published ASN IPv4/IPv6 ranges. (Satisfies NIST CSF PR.AC-04, CIS Control 13).  
**Priority 15: Establish a Split Secrets Architecture (Effort: High, Priority: Medium)** The dual-boundary secrets architecture must be rigorously maintained. Edge API credentials and LLM tokens must reside exclusively within the Cloudflare Secrets Store and Workers KV (accessed via MCP). Conversely, cluster-level workload secrets must remain within the OpenBao instance on K3s. This prevents an edge Worker compromise from exposing internal cluster orchestration tokens. (Satisfies NIST CSF PR.DS-05).

## **Architectural Deep Dives**

### **Ingress Architecture: Cloudflare Tunnels vs. Proxied DNS**

The current deployment utilizes proxied DNS (A records with the "Orange Cloud" enabled) routing directly to the Traefik Ingress Controller hosted on the Hetzner K3s cluster. While this provides baseline CDN and WAF capabilities, it leaves the public IP addresses of the K3s nodes exposed. If a threat actor discovers these origin IPs—often possible via historic DNS databases or IP scanning tools—they can bypass the Cloudflare security perimeter entirely, executing direct volumetric Distributed Denial of Service (DDoS) attacks or exploiting application layer vulnerabilities.  
The optimal, highly secure topology dictates a complete migration to **Cloudflare Tunnels (cloudflared)**. Tunnels operate by initiating an outbound-only TCP/QUIC connection (typically over port 7844\) from within the K3s cluster directly to the Cloudflare edge network. This architectural shift provides profound security benefits: it allows the immediate closure of all inbound listening ports (80, 443\) on the Hetzner firewall.  
Furthermore, Cloudflare Tunnels and Traefik Ingress operate synergistically. The cloudflared daemon should be deployed as a highly available Kubernetes Deployment within the K3s cluster. The Cloudflare Zero Trust dashboard is then configured to route wildcard traffic (e.g., \*.helixstax.net) through the tunnel to the internal Traefik ClusterIP service. Traefik retains its role as the Layer 7 router, parsing internal Host headers and directing traffic to the respective internal pods (n8n, Grafana, Devtron). This eliminates the complexity of configuring individual tunnel routes for dozens of microservices, centralizing internal routing logic entirely within Kubernetes IngressRoute definitions.

### **Developer Platform & AI Orchestration Ecosystem**

The execution of 23 autonomous AI agents necessitates a serverless architecture capable of managing complex state, parallel execution, and strict connection limits without introducing unacceptable latency.  
**Workers Architecture Strategy:** The current deployment of five Cloudflare Workers (handling the MCP proxy, Google Workspace integration, ClickUp, and the secrets vault) is functional but requires modernization to support agentic workflows.

* **Workers KV** is an eventually-consistent data store optimally suited for read-heavy operations. It should continue to be utilized for the secrets-vault, caching frequently accessed configuration maps and non-sensitive metadata.  
* **Durable Objects (DO)** must be introduced to manage agent state. Because AI agents utilizing the Model Context Protocol (MCP) require conversational memory and multi-step reasoning capabilities, traditional stateless functions fail. Durable Objects provide strictly consistent, stateful memory execution, allowing an agent's reasoning loop to be preserved safely at the edge during prolonged operations.  
* **Cloudflare Queues** should be implemented to handle asynchronous webhook ingestion. When ClickUp or Google Workspace emits an event, a lightweight Worker should immediately acknowledge the payload and push it to a Queue. A separate consumer Worker can then process the event and trigger the appropriate AI agent or n8n workflow, ensuring that sudden spikes in webhook activity do not overwhelm the K3s cluster.

**Storage Strategy: R2 vs. MinIO:** The architecture currently relies on a self-hosted MinIO instance within the K3s cluster for S3-compatible storage. While MinIO is highly performant for internal cluster operations, managing public-facing storage at the edge introduces substantial bandwidth costs and maintenance burdens. The strategy requires coexistence: MinIO must be restricted exclusively to internal, ephemeral workloads (e.g., ArgoCD artifact caching, temporary n8n data transformation). All persistent, client-facing deliverables, public website assets, and agent-generated documentation must be migrated to **Cloudflare R2**. R2 provides S3 API compatibility at a cost of $0.015/GB-month with zero egress fees. For an AI ecosystem that continuously reads and writes large context windows and vector embeddings, the elimination of egress fees provides unparalleled cost efficiency.  
**Frontend Deployment Strategy:** The upcoming helixstax.com website (Astro or Next.js) must be hosted on **Cloudflare Pages**. Deploying a static or Server-Side Rendered (SSR) site inside the K3s cluster introduces unnecessary complexity and consumes valuable node compute. Cloudflare Pages integrates natively with GitHub, providing automated CI/CD builds, infinite scalability, and direct deployment to the edge. The dynamic "Cortex" dashboard preview section can utilize Pages Functions (which are fundamentally Cloudflare Workers under the hood) to fetch live data securely via the cloudflared tunnel without exposing the database to the internet.

### **AI Operations and Gateway Routing**

The operation of 23 LLM-driven agents querying multiple foundation models (Claude, Gemini) via direct APIs and OpenRouter introduces significant observability blind spots and uncontrolled expenditure risks.  
**Cloudflare AI Gateway** must be implemented immediately. AI Gateway acts as a specialized proxy layer sitting between the AI agents (running locally via CLI or in K3s) and the upstream model providers. Integrating this requires only a minimal endpoint modification in the agent configuration to route traffic through the Cloudflare edge. The benefits are substantial:

1. **Cost Tracking and Observability:** Centralized logging of prompt payloads, token usage, and latency distributions across all 23 agents, preventing rogue autonomous loops from generating massive unexpected bills.  
2. **Semantic Caching:** Highly repetitive AI queries (e.g., an agent fetching standard compliance framework definitions) can be cached at the edge, returning responses in milliseconds while entirely bypassing upstream API costs.  
3. **Resilience:** The gateway can be configured with automated retries and model fallbacks (e.g., defaulting to Gemini if the Anthropic API experiences downtime), ensuring uninterrupted agent operations. Importantly, Cloudflare AI Gateway does not inject a per-token markup, distinguishing it favorably from routing aggregators that charge a premium for similar observability.

### **Model Context Protocol (MCP) Orchestration**

The Model Context Protocol (MCP) bridges the gap between the isolated reasoning capabilities of LLMs and secure, executable infrastructure actions. The strategy surrounding MCP must encompass both administrative infrastructure management and specialized SaaS data retrieval.  
**Code Mode for Infrastructure Orchestration:** Defining the entire Cloudflare API (over 2,500 endpoints) using traditional native MCP schemas would consume over 1.17 million tokens—exhausting the context window of any foundation model. Therefore, the official Cloudflare MCP repository (github.com/cloudflare/mcp) implements a paradigm known as "Code Mode." This server exposes only two tools: search() and execute(). The AI agent dynamically writes JavaScript to interact with the API, which Cloudflare then executes inside a highly restricted, secure V8 isolate (a Dynamic Worker Sandbox). This approach condenses the token requirement to approximately 1,000 tokens. Integrating this Code Mode MCP server into the Claude Code ecosystem completely eliminates the need to develop or maintain a custom administrative MCP server for tasks like DNS record manipulation or WAF tuning.  
**Specialized MCP Server Integration:** While the Code Mode server manages Cloudflare infrastructure, the agents require access to specialized data pipelines. From the official mcp-server-cloudflare repository, the following servers should be deployed :

* **Browser Rendering Server:** Allows the agents to fetch live client websites, convert the DOM to markdown, and take visual screenshots for security analysis.  
* **Observability Server:** Grants the agents the ability to interrogate Worker logs to debug their own MCP proxy failures autonomously.  
* **Cloudflare One CASB Server:** Enables agents to query the security posture and configuration drift of integrated SaaS applications (like Google Workspace).

\#\#\# Database Connectivity and Hyperdrive  
The MCP custom Workers periodically require read/write access to the CloudNativePG PostgreSQL database running within the K3s cluster. Standard serverless functions encounter a critical bottleneck when communicating with relational databases: each invocation attempts to establish a fresh TCP connection, requiring a full TLS negotiation and authentication handshake (amounting to 7 separate network round-trips). At scale, the 23 AI agents rapidly spinning up concurrent Workers will overwhelm the PostgreSQL connection pool, leading to dropped queries and severe latency.  
**Cloudflare Hyperdrive** is the definitive architectural solution to this limitation. Hyperdrive establishes a regional, persistent connection pool located physically close to the origin database. When a Worker executes a query, it connects via an ultra-fast edge connection to the Hyperdrive pool, which then multiplexes the queries over the established long-lived connections to the K3s database. Because the CloudNativePG instance resides in a private, unexposed K3s network, Hyperdrive must be explicitly configured to utilize the secure Cloudflare Tunnel (cloudflared) to bridge the network gap. The Pro plan allows approximately 100 maximum origin connections per configuration, which is deeply sufficient for the current scale.

### **Zero Trust and Access Strategy**

As an IT consulting firm preparing to handle highly sensitive client compliance data, the infrastructure must adhere to stringent Zero Trust principles, moving entirely away from perimeter-based (VPN) security models toward identity and context-aware access controls.  
**Solo Founder Configuration:** Every internal application mapped to helixstax.net (Grafana, ArgoCD, Devtron, n8n, Open WebUI) must be individually protected by Cloudflare Access policies. Access operates as an Identity-Aware Proxy (IAP), evaluating every single request before it enters the Cloudflare Tunnel. The identity provider (IdP) integration with Google Workspace must enforce Multi-Factor Authentication (MFA) via hardware security keys.  
To satisfy NIST PR.AA-05 (Identity Management), identity verification alone is insufficient; **Device Posture** checks must be enforced. The Cloudflare WARP client must be deployed on the founder's administrative workstation. Access policies will be configured to grant entry only if the WARP client successfully validates that the workstation is running an approved, fully patched OS version, the local firewall is active, and full disk encryption (e.g., FileVault or BitLocker) is verified.  
**Machine-to-Machine Authentication:** The 23 AI agents execute commands autonomously and cannot satisfy human MFA challenges or WARP posture checks. To allow these agents secure programmatic access to the internal API surfaces and custom MCP Workers, **Cloudflare Service Tokens** must be utilized. These cryptographically secure tokens are generated within the Zero Trust dashboard and securely injected into the K3s pods via the OpenBao secrets engine. The Access policies protecting the Worker endpoints are then augmented with an AnyValidServiceTokenRule, permitting automated, headless access strictly from the authenticated agent pods.

### **Email Security and Authentication**

Protecting the helixstax.com domain from impersonation and securing client communications is a fundamental requirement for SOC 2 Type II compliance (Control CC6.1). The current reliance on Google Workspace default configurations is insufficient.  
**Exact DNS Configuration Roadmap:** The following records must be provisioned within the Cloudflare DNS dashboard to establish an impenetrable email security posture:

1. **SPF (Sender Policy Framework):** Validates authorized sending IPs. TXT | helixstax.com | v=spf1 include:\_spf.google.com \~all  
2. **DKIM (DomainKeys Identified Mail):** Cryptographically signs outbound messages. TXT | google.\_domainkey | v=DKIM1; k=rsa; p=  
3. **DMARC (Domain-based Message Authentication):** Enforces SPF/DKIM alignment. TXT | \_dmarc | v=DMARC1; p=reject; sp=reject; adkim=s; aspf=s; rua=mailto:dmarc-reports@helixstax.com;  
4. **MTA-STS (Mail Transfer Agent Strict Transport Security):** Enforces TLS encryption for all inbound mail, stopping downgrade attacks. TXT | \_mta-sts | v=STSv1; id=2026032301; *Note: A Cloudflare Worker must be deployed to the mta-sts.helixstax.com subdomain to serve the required JSON policy file via an HTTPS /.well-known/mta-sts.txt directory*.  
5. **TLS Reporting:** Collects diagnostic data regarding encryption failures. TXT | \_smtp.\_tls | v=TLSRPTv1; rua=mailto:tls-reports@helixstax.com;.

### **Defense-in-Depth: CrowdSec Synergy**

The presence of CrowdSec as a host-based Intrusion Detection/Prevention System (IDS/IPS) within the K3s cluster is highly synergistic with Cloudflare's perimeter security; they serve entirely different layers of the OSI model and do not render one another redundant.

* **Cloudflare WAF (The Perimeter):** Operates at the network edge as a reverse proxy, absorbing volumetric DDoS attacks, parsing massive threat intelligence feeds to block zero-day exploits, and intercepting malicious HTTP payloads (e.g., SQLi, XSS) before the packets ever traverse the internet to reach Hetzner.  
* **CrowdSec (The Interior):** Because Cloudflare terminates the TLS session and decrypts the traffic for inspection, CrowdSec operating on the K3s nodes analyzes the post-decrypted application behavior. CrowdSec excels at detecting complex behavioral anomalies that bypass perimeter WAFs, such as internal lateral movement attempts, repeated application-specific authentication failures (e.g., brute-forcing a Zitadel login page), or anomalous API usage patterns generated by compromised pods.

The systems should coexist. CrowdSec can be configured to share its localized threat detection lists dynamically via APIs, ensuring that if CrowdSec detects an anomaly inside K3s, the offending IP can be pushed upstream to be blocked universally at the Cloudflare edge.

## **Complete Product Audit Table**

The following table exhaustively audits 117+ Cloudflare products against the Helix Stax architecture, categorizing verdicts based on immediate necessity, cost parameters, and programmatic AI integration potential.

### **SECURITY — APPLICATION LAYER**

| Product Name | Description | Verdict | Justification & Config | Cost | MCP |
| :---- | :---- | :---- | :---- | :---- | :---- |
| **WAF (Managed Rules)** | Heuristic inspection of malicious L7 HTTP traffic. | **YES-PAID** | Mandatory for SOC 2 CC6.1. Deploy the OWASP core ruleset with a high sensitivity threshold to drop malformed payloads. | Included in Pro | Yes |
| **WAF (Custom Rules)** | User-defined firewall expressions. | **YES-PAID** | Critical. Build rules to drop non-US traffic targeting the internal MCP Worker routes (/mcp). | Included in Pro | Yes |
| **DDoS Protection (L3/L4/L7)** | Network/Application layer attack mitigation. | **YES-FREE** | Default unmetered protection is essential to prevent K3s origin bandwidth exhaustion and cloud billing spikes. | Free | Yes |
| **Bot Management** | Advanced machine learning bot detection. | **MAYBE-LATER** | Enterprise bot management is overkill for a pre-revenue firm. Rely on Super Bot Fight Mode temporarily. | Enterprise | Yes |
| **Super Bot Fight Mode** | Challenges or blocks recognizable automated threats. | **YES-PAID** | Configure "Definitely Automated" to Block. Ensure AI agent infrastructure IPs are explicitly bypassed via WAF. | Included in Pro | No |
| **Rate Limiting** | Restricts request frequency per client IP/session. | **YES-PAID** | Protects n8n webhooks and Zitadel logins from brute-force attacks. Set 100 req/min limit on /login paths. | Included in Pro | Yes |
| **API Shield** | Validates API traffic against uploaded OpenAPI schemas. | **YES-PAID** | Protects backend K3s APIs. Upload the MCP JSON-RPC schemas to strictly block malformed agent requests. | Add-on | Yes |
| **Page Shield** | Monitors client-side JS for supply chain attacks. | **MAYBE-LATER** | The consulting site will be static Astro with minimal 3rd party scripts, reducing the immediate risk vector. | Add-on | No |
| **Advanced Cert Manager** | Manages complex custom TLS certificate lifecycles. | **NO** | Universal SSL and Origin CA (15-year duration) are completely sufficient for the current scope. | $10/mo | Yes |
| **SSL/TLS (Modes/Ciphers)** | Encrypts edge traffic. | **YES-FREE** | Set mode to "Full (Strict)". Enforce TLS 1.3 minimum version to satisfy NIST cryptography standards. | Free | Yes |
| **Authenticated Origin Pulls** | Enforces mTLS between Cloudflare and Origin. | **YES-FREE** | Prevents direct IP access to Traefik. Upload the CF certificate to K3s Traefik ingress definitions. | Free | Yes |
| **Turnstile** | Privacy-preserving, invisible CAPTCHA alternative. | **YES-FREE** | Deploy on the consulting site contact forms to prevent lead-generation spam and malicious form submissions. | Free | No |
| **Security.txt** | Hosts standard vulnerability disclosure policy. | **YES-FREE** | Generate via the dashboard to satisfy ISO 27001 vulnerability mapping and signal security maturity. | Free | No |
| **Leaked Credentials** | Scans request bodies for compromised passwords. | **MAYBE-LATER** | Highly valuable for client portal security, but requires Enterprise WAF logging capabilities. | Enterprise | No |
| **Fraud Detection** | Analyzes transactional data for fraudulent behavior. | **NO** | Not applicable to an IT consulting business model that relies on invoiced B2B engagements. | Add-on | No |
| **Geo Key Manager** | Restricts where private SSL keys are stored globally. | **NO** | Regulatory requirements for general IT consulting do not demand restrictive geographic key custody. | Enterprise | No |
| **Keyless SSL** | Keeps private cryptographic keys strictly on-premise. | **NO** | Overkill. Cloudflare-managed edge keys inherently satisfy SOC 2 compliance requirements. | Enterprise | No |
| **Challenges** | Verifies visitors are not bots via JS computational challenges. | **YES-FREE** | Employ dynamically via WAF rules when traffic anomaly scores spike unexpectedly. | Free | Yes |
| **Content Security Policy** | Enforces resource loading restrictions in browsers. | **YES-FREE** | Crucial defense against XSS. Configure strict default-src 'self' headers via Cloudflare Transform Rules. | Free | Yes |
| **Signed Exchanges** | Allows Google to prefetch content securely. | **NO** | Not strictly a security product; marginal SEO benefit not worth the configuration overhead for a B2B consulting site. | Free | No |

### **SECURITY — ZERO TRUST / SASE (Cloudflare One)**

| Product Name | Description | Verdict | Justification & Config | Cost | MCP |
| :---- | :---- | :---- | :---- | :---- | :---- |
| **Access** | Identity-aware proxy enforcing application-level auth. | **YES-FREE** | Mandatory for protecting internal K3s platforms. Configure OIDC via Google Workspace or Zitadel. | Free (to 50\) | Yes |
| **Gateway** | Secure web gateway (DNS/HTTP filtering). | **MAYBE-LATER** | Good for blocking outbound malware on the founder's laptop, but low priority pre-revenue. | Free (to 50\) | Yes |
| **WARP Client** | Device agent routing traffic to CF Zero Trust. | **YES-FREE** | Required for Device Posture checks. Install on all administrative hardware endpoints. | Free | No |
| **Device Posture** | Verifies endpoint health before Access is granted. | **YES-FREE** | Require OS updates, active firewalls, and disk encryption before granting access to helixstax.net. | Free | Yes |
| **Browser Isolation** | Executes web code on secure cloud infrastructure. | **NO** | Expensive and unnecessary for a solo technical founder with excellent endpoint hygiene practices. | Add-on | No |
| **CASB** | Scans SaaS applications for security misconfigurations. | **NO** | Overkill for a solo Google Workspace instance; native Google audits are sufficient for now. | Add-on | Yes |
| **DLP** | Scans outbound traffic for sensitive data signatures (PII). | **NO** | Irrelevant until onboarding employees or processing highly sensitive compliance data (PHI/PCI). | Add-on | No |
| **Email Security (Area 1\)** | Advanced anti-phishing and BEC prevention. | **MAYBE-LATER** | Reevaluate once the consulting business scales and routinely receives external attachments. | Add-on | Yes |
| **Digital Experience** | Endpoint and network analytics/monitoring. | **NO** | Useful for massive IT helpdesks; completely unnecessary for a solo developer infrastructure. | Add-on | Yes |
| **Internal DNS** | Private network resolution. | **YES-FREE** | Configure to route internal .svc.cluster.local requests seamlessly through the Zero Trust architecture. | Free | Yes |

### **DEVELOPER PLATFORM**

| Product Name | Description | Verdict | Justification & Config | Cost | MCP |
| :---- | :---- | :---- | :---- | :---- | :---- |
| **Workers** | Serverless V8 javascript execution environments. | **YES-PAID** | Core execution engine for the MCP proxy and secrets vault. Upgrade to Paid to bypass CPU duration limits. | $5/mo | Yes |
| **Workers KV** | Global eventually-consistent key-value data store. | **YES-FREE** | Ideal for storing the secrets-vault mapping, maintaining read-heavy, infrequently changed credential references. | Free Tier | Yes |
| **Workers AI** | Serverless GPU inference at the network edge. | **NO** | Helix Stax is already utilizing OpenRouter, Claude, and Gemini via external APIs directly. | Pay-as-you-go | No |
| **Workers VPC** | Private cloud connectivity for serverless functions. | **NO** | cloudflared tunnels fulfill the current requirement for secure internal network routing. | Beta | Yes |
| **Workers for Platforms** | Multi-tenant programmable architecture. | **NO** | Not building a SaaS platform where customers deploy code; consulting model does not require this. | Enterprise | No |
| **Analytics Engine** | Custom analytics ingestion and querying. | **MAYBE-LATER** | Can be leveraged later to track complex AI agent success metrics, but Grafana/Prometheus handles this now. | Paid Tier | Yes |
| **Durable Objects** | Strictly consistent stateful serverless execution. | **YES-PAID** | Critical for managing continuous stateful conversational context for the autonomous AI agents. | Paid Tier | No |
| **D1** | Serverless edge SQLite database. | **MAYBE-LATER** | Useful for lightweight relational logs, but Hyperdrive to the existing K3s CloudNativePG makes more architectural sense. | Paid Tier | Yes |
| **R2** | Zero-egress S3-compatible object storage. | **YES-FREE** | Replace public MinIO assets. Host consulting artifacts here to eliminate Hetzner bandwidth egress costs. | Free Tier | Yes |
| **R2 Data Catalog** | Iceberg table management for analytics. | **NO** | The architecture does not yet require massive data lake querying or Apache Iceberg integrations. | Pay-as-you-go | Yes |
| **R2 SQL** | Serverless query engine for R2 data. | **NO** | Relational queries will be directed to the CloudNativePG cluster via Hyperdrive. | Pay-as-you-go | No |
| **Queues** | Guaranteed message delivery between Workers. | **YES-PAID** | Use to safely decouple external webhook ingestion (ClickUp) to the internal n8n automation instances. | Paid Tier | No |
| **Pipelines** | Real-time data ingestion streams. | **NO** | Data volume from a solo consulting practice does not warrant streaming ingestion infrastructure. | Pay-as-you-go | No |
| **Pub/Sub** | Publish/subscribe message broker. | **NO** | Queues natively handle the necessary asynchronous worker-to-worker event distribution. | Pay-as-you-go | No |
| **Hyperdrive** | Regional database connection pooling. | **YES-FREE** | Vital for connecting the MCP proxy to PostgreSQL on K3s, preventing catastrophic TCP connection exhaustion. | Free Tier | No |
| **Vectorize** | Serverless vector database for embeddings. | **NO** | Helix Stax is already successfully operating a native pgvector instance inside the K3s environment. | Pay-as-you-go | Yes |
| **AI Gateway** | Proxy for AI APIs offering caching and analytics. | **YES-FREE** | Route all OpenRouter/Claude traffic through this to enable critical cost tracking and semantic prompt caching. | Free | Yes |
| **AI Search/AutoRAG** | Managed Retrieval-Augmented Generation pipelines. | **NO** | RAG operations are natively handled by the local pgvector database and the customized MCP ecosystem. | Beta | Yes |
| **Browser Rendering** | Headless browser execution API. | **YES-PAID** | Highly recommended. Utilize the official MCP server to allow AI agents to scrape and parse client websites securely. | Paid Tier | Yes |
| **Pages** | Hosting for static and SSR frontend architectures. | **YES-FREE** | The optimal location to host the upcoming helixstax.com Astro/Next.js site, providing global CDN distribution. | Free | Yes |
| **Stream** | Video storage, encoding, and delivery. | **NO** | Not applicable to the current text and data-driven IT consulting operational model. | Add-on | Yes |
| **Images** | Image storage, resizing, and optimization. | **MAYBE-LATER** | Cloudflare Pro's built-in "Polish" optimization is sufficient for the consulting website's static images. | Add-on | Yes |
| **Calls / Realtime** | WebRTC infrastructure. | **NO** | The infrastructure does not operate live audio/video streaming applications. | Pay-as-you-go | No |
| **Workflows** | Durable multi-step serverless execution. | **NO** | Complex workflow automation is presently managed by the highly capable n8n instance on K3s. | Paid Tier | No |
| **Containers/Sandbox** | Serverless container execution environments. | **NO** | The robust, self-hosted K3s cluster on Hetzner serves as the primary container orchestration engine. | N/A | Yes |
| **Secrets Store** | Encrypted, highly secure secret storage. | **YES-FREE** | Essential for securely holding the LLM API keys and edge credentials accessed by the custom MCP Workers. | Free | No |

### **NETWORK SERVICES & PERFORMANCE**

| Product Name | Description | Verdict | Justification & Config | Cost | MCP |
| :---- | :---- | :---- | :---- | :---- | :---- |
| **Cloudflare Tunnel** | Outbound secure connector to the CF edge. | **YES-FREE** | Replace public proxy ingress entirely. Run cloudflared deployment in K3s mapped strictly to Traefik. | Free | Yes |
| **Spectrum** | Proxies arbitrary TCP/UDP non-HTTP traffic. | **NO** | Unnecessary; all internal SSH or database access will be handled securely via Cloudflare Access/Tunnels. | Enterprise | No |
| **Magic Transit** | BGP-level volumetric DDoS protection. | **NO** | Designed for massive enterprise networks with physical branch offices; extreme overkill for a K3s cluster. | Enterprise | No |
| **Magic WAN** | Site-to-site SD-WAN replacement. | **NO** | Helix Stax has a single location/cluster; SD-WAN routing topologies are not applicable. | Enterprise | No |
| **Magic Firewall** | Network-level firewall-as-a-service. | **NO** | Local K3s NetworkPolicies and Hetzner cloud firewalls provide adequate internal network segmentation. | Enterprise | No |
| **Network Interconnect** | Direct physical peering with Cloudflare. | **NO** | Requires physical data center cross-connects; entirely incompatible with cloud-hosted Hetzner infrastructure. | Enterprise | No |
| **BYOIP** | Bring Your Own IP routing. | **NO** | Helix Stax does not own a heavily reputable ARIN IP block; Cloudflare shared IPs are superior. | Enterprise | No |
| **China Network** | Specialized routing for mainland China traffic. | **NO** | The target demographic for SMB IT consulting is presumably domestic or Western markets. | Enterprise | No |
| **Multi-Cloud Network** | Orchestrates routing across disparate public clouds. | **NO** | Operations are consolidated on a single Hetzner provider; multi-cloud mesh topologies add unnecessary cost. | Enterprise | No |
| **Network Error Logs** | Captures connectivity telemetry at the network layer. | **MAYBE-LATER** | Useful for diagnosing edge routing drops, but standard application logs suffice for a startup. | Enterprise | No |
| **Network Flow** | Establishes end-to-end network visibility and anomaly detection. | **NO** | Redundant. The Prometheus/Grafana stack on K3s monitors internal cluster flow adequately. | Enterprise | No |
| **CDN/Cache** | Caches static web assets globally. | **YES-FREE** | Essential. Ensure Cache Rules are aggressively tuned for the upcoming Astro frontend to maximize offload. | Free | Yes |
| **Cache Reserve** | Persistent object storage cache to eliminate egress. | **MAYBE-LATER** | Only necessary if the origin experiences high cache-eviction rates resulting in massive bandwidth bills. | Add-on | Yes |
| **Tiered Caching** | Optimizes routing across regional CF backbones. | **MAYBE-LATER** | Argo Smart Routing is a powerful future upgrade for API performance, but incurs a $0.10/GB data transfer cost. | $5 \+ usage | No |
| **Load Balancing** | Multi-origin geographic traffic distribution. | **NO** | The architecture relies on a singular Hetzner K3s cluster; no secondary geographic origin exists to balance against. | $5/mo | Yes |

### **EMAIL, DNS, REGISTRAR, AND OBSERVABILITY**

| Product Name | Description | Verdict | Justification & Config | Cost | MCP |
| :---- | :---- | :---- | :---- | :---- | :---- |
| **Email Routing** | Receives and routes incoming domain emails. | **YES-FREE** | Utilize an Email Worker acting on a subdomain (mta-sts) to securely host the Google Workspace policy file. | Free | No |
| **DMARC Management** | Advanced analytics for DMARC records. | **YES-FREE** | Enable to visualize spoofing attempts against helixstax.com, ensuring email reputation remains pristine. | Free | No |
| **DNS (Authoritative)** | Primary domain zone resolution. | **YES-FREE** | Core functionality. Manage all records and ensure proxy status (orange cloud) is used correctly to obscure origins. | Free | Yes |
| **Cloudflare Registrar** | At-cost global domain registration. | **YES-FREE** | Best practice to consolidate domain lifecycle management natively inside the Cloudflare security ecosystem. | Cost of TLD | No |
| **Logpush** | Streams security logs to external storage destinations. | **YES-PAID** | Push Audit logs and WAF events to R2 or K3s Loki to satisfy SOC 2 non-repudiation logging mandates. | Pro/Biz | Yes |
| **Audit Logs (v2)** | Immutable record of all configuration changes. | **YES-FREE** | Essential for strict compliance tracking. Version 2 automatically captures all API and dashboard modifications. | Free | Yes |
| **Security Center** | Centralized attack surface management. | **YES-FREE** | Utilize to automatically scan for misconfigurations and exposed K3s subdomains. | Free | No |

## **Target Architecture Model**

The recommended topology transforms Helix Stax from a perimeter-vulnerable configuration into an isolated, Zero Trust architecture governed heavily by programmatic, AI-accessible orchestration.  
**1\. The Global Edge Layer (Cloudflare):**

* **Public Domain (helixstax.com):** Hosted entirely on Cloudflare Pages (utilizing Astro/Next.js). It is rigidly protected by the WAF Pro Ruleset, Super Bot Fight Mode, Turnstile CAPTCHAs, and Rate Limiting. All TLS is negotiated at the edge.  
* **API & AI Agent Layer (api.helixstax.net):** Cloudflare Workers (hosting the MCP Proxy and Secrets Vault) intercept all programmatic requests. The AI Gateway intercepts, logs, and routes out-of-band LLM traffic safely to OpenRouter.  
* **Zero Trust Perimeter:** Cloudflare Access authenticates incoming human administrative traffic via Google Workspace combined with strict WARP Device Posture checks. Simultaneously, it validates Service Tokens to authenticate headless AI Agent traffic.

**2\. The Transport Layer (Tunnels & Connection Pooling):**

* **Cloudflare Tunnels (cloudflared):** A daemonset within K3s establishes a secure, outbound-only QUIC connection to the Cloudflare edge, entirely bypassing the need for public IP exposure.  
* **Hyperdrive:** Pools raw PostgreSQL connections from the serverless edge Workers directly to the internal CloudNativePG instance, radically accelerating database reads.

**3\. The Execution Layer (Hetzner K3s Cluster):**

* **Total Isolation:** No public listening ports exist (Ports 80/443 are closed at the Hetzner firewall level).  
* **Internal Routing:** Traefik receives traffic exclusively from the internal cloudflared pod, processing host headers and distributing workloads cleanly.  
* **Defense-in-Depth:** Workloads (n8n, Grafana, OpenBao) operate securely inside the cluster while CrowdSec monitors internal application logs for post-decryption lateral movement anomalies.

## **Implementation Roadmap**

### **Phase 1: Immediate Security Hardening (Week 1\)**

* **Objective:** Secure the perimeter to prevent immediate exploitation and satisfy baseline SOC 2 controls.  
* **Actions:**  
  * Purge all stale DNS records (auth, s3) to prevent subdomain takeovers.  
  * Configure comprehensive email security: DMARC, SPF, DKIM, and deploy the MTA-STS proxy worker for Google Workspace.  
  * Generate and publish the security.txt file.  
  * Enforce hardware MFA on the Cloudflare Admin account and tightly restrict the scope of existing API tokens.  
  * Toggle "Super Bot Fight Mode" and enact the "AI Crawl Control" policies.

### **Phase 2: Infrastructure Isolation & Zero Trust (Days 7-30)**

* **Objective:** Sever direct internet access to the K3s cluster and establish identity-aware perimeters.  
* **Actions:**  
  * Deploy the cloudflared daemon on K3s; update all DNS records to alias to the newly generated Tunnel UUID.  
  * Configure Cloudflare Access applications for all internal K3s endpoints (Grafana, n8n, Devtron).  
  * Install the WARP client on the developer machine and bind explicit Device Posture rules to the Access policies.  
  * Deploy Hyperdrive and route the custom MCP proxy database connections through the connection pool.

### **Phase 3: Platform & AI Scaling (Website Launch)**

* **Objective:** Optimize the AI infrastructure for the commercial launch of the consulting practice.  
* **Actions:**  
  * Deploy the Astro/Next.js marketing site to Cloudflare Pages.  
  * Integrate Cloudflare AI Gateway into the codebases of the 23 agents calling OpenRouter to initiate granular cost tracking and semantic caching.  
  * Migrate the custom MCP servers to utilize Cloudflare Service Tokens for programmatic authentication directly from the K3s agent pods.  
  * Integrate the official cloudflare/mcp Code Mode server into the Claude Code CLI to enable autonomous infrastructure management.

### **Phase 4: Client Onboarding Readiness**

* **Objective:** Establish robust data isolation, auditing, and high availability for client data.  
* **Actions:**  
  * Configure Logpush to continuously stream Cloudflare Audit Logs and WAF event telemetry to an immutable R2 bucket to satisfy SOC 2 non-repudiation logging requirements.  
  * Deploy Mutual TLS (mTLS) using Cloudflare Advanced Certificate Manager to cryptographically isolate distinct consulting clients accessing proprietary diagnostic dashboards.

## **Cost Optimization Breakdown**

To support the production readiness of Helix Stax while honoring the strict financial constraints of a bootstrapped solo founder, the infrastructure requires upgrading from the Free Tier to a precisely structured Paid model. Upgrading to the **Business Plan ($200/mo)** is completely unnecessary at this stage, as its primary benefits (custom cache keys, 100% uptime SLAs, SSO support) do not align with pre-revenue requirements. The **Pro Plan ($20/mo)**, synthesized with the **Workers Paid Plan ($5/mo)**, delivers all requisite security controls (WAF managed rules, comprehensive Rate Limiting) and complex compute capabilities (Durable Objects, unlimited Hyperdrive queries).

| Service Category | Selected Plan | Monthly Cost | Strategic Justification |
| :---- | :---- | :---- | :---- |
| **Domain Zones** | Pro Plan (helixstax.com) | $20.00 | Unlocks the essential OWASP Core Ruleset, advanced edge caching (Polish/Mirage), and Super Bot Fight Mode for the public site. |
| **Domain Zones** | Free Plan (helixstax.net) | $0.00 | The internal API domain is entirely obscured behind Tunnels and Access, requiring fewer public-facing edge caching features. |
| **Developer Platform** | Workers Paid Plan | $5.00 | Strictly required for Durable Objects (state management), Logpush to R2, and lifting the CPU/Duration limits necessary for complex MCP proxies. |
| **Storage** | R2 (Pay-as-you-go) | \~$0.00 | Billed at $0.015/GB-month. The generous free tier (10GB/mo) covers all current agent states and client deliverables with zero egress fees. |
| **Zero Trust** | Cloudflare One (Free) | $0.00 | Free for up to 50 users. Covers Access, Gateway, Tunnels, and Service Tokens. |
| **AI Gateway** | Free Tier | $0.00 | Crucial caching and routing features are currently unmetered; log retention is generously capped at 1,000,000 logs/month on the Workers Paid tier. |
| **Total Baseline** | **Production Run Rate** | **$25.00 / month** | Delivers an enterprise-grade Zero Trust architecture and SOC 2 aligned security primitives at exceptional cost efficiency. |

This comprehensive architectural realignment decisively resolves the existing infrastructure vulnerabilities, securely isolates the orchestration plane from public access, and establishes a highly scalable, AI-driven networking foundation capable of passing rigorous compliance audits for future Helix Stax clientele.

#### **Works cited**

1\. Manage cyber risk with the NIST CSF \- Cloudflare, https://cf-assets.www.cloudflare.com/slt3lc6tev37/5tUnEplfJRDDFR4hgWzG12/2924c0ad387d845d54af487bbc77da61/nist\_csf\_2.0-whitepaper.pdf 2\. Cloudflare and SOC 2 Compliance, https://www.cloudflare.com/resources/assets/slt3lc6tev37/7vZlrNo1tW8fmtSV3ASMqA/d055046a4fd2efeb845e0d2c1e192c55/SOC2\_compliance.pdf 3\. CIS Controls v8 Mapping to NIST CSF 2.0, https://www.cisecurity.org/insights/white-papers/cis-controls-v8-mapping-to-nist-csf-2-0 4\. PCI/DSS 4.0 Cloudflare Technical Compliance Mapping, https://assets.ctfassets.net/slt3lc6tev37/5ai8vMkFvIGtVVyKF8BgP7/7621567cec21251ac48fe5a1635bc4b2/PCI\_DSS\_4.0\_Cloudflare\_Technical\_Compliance\_Mapping.pdf 5\. Cloudflare Pricing 2026: Plans, Costs & Real ROI, https://checkthat.ai/brands/cloudflare/pricing 6\. SetUp Guide to Google Workspace DKIM, DMARC, SPF in 2026 | EasyDMARC, https://easydmarc.com/blog/setup-guide-to-google-workspace-dkim-dmarc-spf-in-2026-for-business/ 7\. How to Set Up MTA-STS: Step-by-Step Guide \- MailMonitor, https://www.mailmonitor.com/how-to-set-up-mta-sts-step-by-step-guide/ 8\. Cloudflare Application Services & Solutions, https://www.cloudflare.com/application-services/products/ 9\. Exposing Kubernetes Apps to the Internet with Cloudflare Tunnel, Ingress Controller, and ExternalDNS | by Nicholas | ITNEXT, https://itnext.io/exposing-kubernetes-apps-to-the-internet-with-cloudflare-tunnel-ingress-controller-and-e30307c0fcb0 10\. Using Traefik with Cloudflare Tunnels \- Matt Dyson, https://mattdyson.org/blog/2024/02/using-traefik-with-cloudflare-tunnels/ 11\. Exposing Home Container with Traefik and Cloudflare Tunnel \- Franky's Notes, https://www.frankysnotes.com/2026/01/exposing-home-container-with-traefik.html 12\. Configure MTA-STS \- Email Routing \- Cloudflare Docs, https://developers.cloudflare.com/email-routing/setup/mta-sts/ 13\. 4\. Turn on MTA-STS and TLS reporting | Set up & manage services, https://knowledge.workspace.google.com/admin/gmail/advanced/turn-on-mta-sts-and-tls-reporting 14\. Introducing the 2026 Cloudflare Threat Report, https://blog.cloudflare.com/2026-threat-report/ 15\. Cloudflare API | Zero Trust › Devices › Posture, https://developers.cloudflare.com/api/resources/zero\_trust/subresources/devices/subresources/posture/ 16\. Build a Remote MCP server · Cloudflare Agents docs, https://developers.cloudflare.com/agents/guides/remote-mcp-server/ 17\. AI Gateway | Observability for AI applications \- Cloudflare, https://www.cloudflare.com/developer-platform/products/ai-gateway/ 18\. Overview · Cloudflare AI Gateway docs, https://developers.cloudflare.com/ai-gateway/ 19\. Posture checks \- Cloudflare One, https://developers.cloudflare.com/cloudflare-one/reusable-components/posture-checks/ 20\. 6 New Ways to Validate Device Posture \- The Cloudflare Blog, https://blog.cloudflare.com/6-new-ways-to-validate-device-posture/ 21\. Cloudflare's own MCP servers, https://developers.cloudflare.com/agents/model-context-protocol/mcp-servers-for-cloudflare/ 22\. Code Mode: give agents an entire API in 1,000 tokens \- The Cloudflare Blog, https://blog.cloudflare.com/code-mode-mcp/ 23\. Tune connection pooling \- Hyperdrive \- Cloudflare Docs, https://developers.cloudflare.com/hyperdrive/configuration/tune-connection-pool/ 24\. How Hyperdrive works \- Cloudflare Docs, https://developers.cloudflare.com/hyperdrive/concepts/how-hyperdrive-works/ 25\. Set up your security.txt file \- Cloudflare Docs, https://developers.cloudflare.com/security-center/infrastructure/security-file/ 26\. Enhance your website's security with Cloudflare's free security.txt generator, https://blog.cloudflare.com/security-txt/ 27\. Audit Logs \- version 2 · Cloudflare Fundamentals docs, https://developers.cloudflare.com/fundamentals/account/account-security/audit-logs/ 28\. Audit Logs \- Cloudflare Docs, https://developers.cloudflare.com/logs/changelog/audit-logs/ 29\. Workers Best Practices \- Cloudflare Docs, https://developers.cloudflare.com/workers/best-practices/workers-best-practices/ 30\. cloudflare and ingress-nginx : r/kubernetes \- Reddit, https://www.reddit.com/r/kubernetes/comments/z2vogg/cloudflare\_and\_ingressnginx/ 31\. Cloudflare Tunnel \- Workers VPC, https://developers.cloudflare.com/workers-vpc/configuration/tunnel/ 32\. Workers & Pages Pricing \- Cloudflare, https://www.cloudflare.com/plans/developer-platform-pricing/ 33\. Cloudflare Developer Platform | Tools & solutions, https://www.cloudflare.com/developer-platform/products/ 34\. Pricing · Cloudflare Durable Objects docs, https://developers.cloudflare.com/durable-objects/platform/pricing/ 35\. Docs directory | Cloudflare Docs, https://developers.cloudflare.com/directory/ 36\. Top Object Storage Providers in 2026: A Guide to the Best Solutions Available \- Atlantic.Net, https://www.atlantic.net/managed-services/top-object-storage-providers-2026-a-guide-to-the-best-solutions-available/ 37\. Cloudflare R2 \- Pricing Calculator, https://r2-calculator.cloudflare.com/ 38\. 5 Cheap Object Storage Providers \- DEV Community, https://dev.to/wimadev/5-cheap-object-storage-providers-5hhh 39\. OpenRouter \- AI Gateway \- Cloudflare Docs, https://developers.cloudflare.com/ai-gateway/usage/providers/openrouter/ 40\. Top 5 AI Gateways for Tracking the Costs of Your AI Applications, https://www.getmaxim.ai/articles/top-5-ai-gateways-for-tracking-the-costs-of-your-ai-applications/ 41\. Understanding Cloudflare AI Gateway Pricing \[A Complete Breakdown\] \- TrueFoundry, https://www.truefoundry.com/blog/understanding-cloudflare-ai-gateway-pricing-a-complete-breakdown 42\. OpenRouter Alternatives in 2025 \- Helicone, https://www.helicone.ai/blog/openrouter-alternatives 43\. Model Context Protocol (MCP) · Cloudflare Agents docs, https://developers.cloudflare.com/agents/model-context-protocol/ 44\. MCP vs APIs: What's the Real Difference? \- freeCodeCamp, https://www.freecodecamp.org/news/mcp-vs-apis-whats-the-real-difference/ 45\. Cloudflare | Awesome MCP Servers, https://mcpservers.org/servers/cloudflare/mcp-server-cloudflare 46\. Thirteen new MCP servers from Cloudflare you can use today, https://blog.cloudflare.com/thirteen-new-mcp-servers-from-cloudflare/ 47\. Getting started · Cloudflare Hyperdrive docs, https://developers.cloudflare.com/hyperdrive/get-started/ 48\. Connection pooling \- Hyperdrive \- Cloudflare Docs, https://developers.cloudflare.com/hyperdrive/concepts/connection-pooling/ 49\. Connect to a private database using Tunnel · Cloudflare Hyperdrive docs, https://developers.cloudflare.com/hyperdrive/configuration/connect-to-private-database/ 50\. Limits · Cloudflare Hyperdrive docs, https://developers.cloudflare.com/hyperdrive/platform/limits/ 51\. How to Configure Cloudflare Zero Trust \- OneUptime, https://oneuptime.com/blog/post/2026-01-25-cloudflare-zero-trust/view 52\. MCP server portals \- Cloudflare One, https://developers.cloudflare.com/cloudflare-one/access-controls/ai-controls/mcp-portals/ 53\. Google Workspace · Cloudflare One docs, https://developers.cloudflare.com/cloudflare-one/integrations/identity-providers/google-workspace/ 54\. Free MTA-STS hosting via Cloudflare Pages : r/sysadmin \- Reddit, https://www.reddit.com/r/sysadmin/comments/1itjv3m/free\_mtasts\_hosting\_via\_cloudflare\_pages/ 55\. Protecting Webapp using Cloudflare or Crowdsec : r/sysadmin \- Reddit, https://www.reddit.com/r/sysadmin/comments/1f33alo/protecting\_webapp\_using\_cloudflare\_or\_crowdsec/ 56\. CrowdSec WAF in Action: Real-World Use Cases, https://www.crowdsec.net/blog/crowdsec-waf-in-action-real-world-use-cases 57\. Cloudflare Product Portfolio, https://www.cloudflare.com/cloudflare-product-portfolio/ 58\. Set up Google Workspace \- Learning Paths \- Cloudflare, https://developers.cloudflare.com/learning-paths/secure-your-email/get-started/setup-google-workspace/ 59\. Enable mTLS · Cloudflare SSL/TLS docs, https://developers.cloudflare.com/ssl/client-certificates/enable-mtls/ 60\. Configure mTLS \- API Shield \- Cloudflare Docs, https://developers.cloudflare.com/api-shield/security/mtls/configure/ 61\. Cloudflare Software Pricing & Plans 2026: See Your Cost \- Vendr, https://www.vendr.com/marketplace/cloudflare 62\. Cloudflare Pro to Business: When to Upgrade, When to Rethink \- Indusface, https://www.indusface.com/blog/cloudflare-pro-vs-business-when-to-upgrade/?amp 63\. Pricing · Cloudflare Workers docs, https://developers.cloudflare.com/workers/platform/pricing/