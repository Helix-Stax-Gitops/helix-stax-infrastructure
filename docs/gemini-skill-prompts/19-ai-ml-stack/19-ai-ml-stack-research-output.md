Of course. This is an excellent use case for a detailed research document. Here is the comprehensive AI & ML Stack reference for Helix Stax, formatted for your AI agents.

***

# Ollama

## ## SKILL.md Content
Core reference for daily operations and troubleshooting.

### CLI Commands (Common)
Execute inside the Ollama pod: `kubectl exec -it ollama-0 -c ollama -- bash`

| Command | Description | Example |
| :--- | :--- | :--- |
| `ollama pull <model>` | Download a model from the registry. | `ollama pull phi3:mini` |
| `ollama list` | List all downloaded models, size, and last updated. | `ollama list` |
| `ollama rm <model>` | Remove a model and its data. | `ollama rm gemma2:2b` |
| `ollama run <model>` | Start an interactive chat session (for debugging). | `ollama run llama3.2:3b` |
| `ollama show --modelfile <model>` | Show the Modelfile for a downloaded model. | `ollama show --modelfile phi3:mini` |
| `ollama create -f <Modelfile>` | Create a custom model from a Modelfile. | `ollama create helix-assistant -f ./HelixModelfile` |

### K3s Management
- **Check Pod Status**: `kubectl get pod -l app.kubernetes.io/name=ollama`
- **View Logs**: `kubectl logs -f ollama-0 -c ollama`
- **Restart Pod**: `kubectl delete pod ollama-0` (StatefulSet will recreate it)
- **Update Image**: Modify `image.tag` in `values.yaml` and run `helm upgrade`.

### Troubleshooting Decision Tree

| Symptom | Probable Cause | Fix |
| :--- | :--- | :--- |
| **Open WebUI reports "Ollama is not running"** | 1. Ollama pod is down. <br> 2. K3s service name is wrong. <br> 3. NetworkPolicy is blocking access. | 1. `kubectl get pods -l app=ollama` and check status. <br> 2. Verify Open WebUI env `OLLAMA_BASE_URL` is `http://ollama.default.svc.cluster.local:11434`. <br> 3. Check for any `NetworkPolicy` artifacts. |
| **API returns 503 or request times out** | 1. Model is not loaded (cold start). <br> 2. Not enough RAM to load the model (OOM). <br> 3. Concurrent request limit reached. | 1. Wait 30-60s. Pre-warm models with `keep_alive`. <br> 2. `kubectl logs ollama-0` for "out of memory" errors. Increase pod memory requests/limits. <br> 3. Ollama queues requests by default. This is normal. |
| **Inference is very slow** | 1. CPU is under-provisioned. <br> 2. Context window (`num_ctx`) is too large. | 1. Expected on CPU. Ensure pod CPU requests/limits are adequate (e.g., `4` cores). <br> 2. Reduce `num_ctx` in API calls or Modelfile for specific tasks. |
| **Model disappears after pod restart** | `PersistentVolumeClaim` is not configured or mounted correctly. | Ensure the `StatefulSet` uses a `volumeClaimTemplate` and mounts it at `/root/.ollama`. |

### Integration Points
- **Open WebUI**: Connects via K3s service `http://ollama.default.svc.cluster.local:11434` (set via `OLLAMA_BASE_URL`).
- **n8n**: Calls Ollama REST API directly via HTTP Request node. Use the same cluster-internal service URL.
- **Prometheus**: Scrape `http://ollama.default.svc.cluster.local:11434/metrics`.
- **Loki**: Pod logs are automatically collected by the cluster's logging agent (e.g., Promtail).

---

## ## reference.md Content
Deep specifications for deployment, configuration, and API usage.

### K3s Deployment (StatefulSet)
A `StatefulSet` is preferred over a `Deployment` to ensure stable network identity (`ollama-0`) and persistent storage for models.

- **Helm Chart**: While community charts exist, a direct manifest provides more control for this specific use case.
- **Resource Requests/Limits**: Memory is the primary constraint. **Rule of thumb: `(Model Size) + 1GB` for base overhead.** For a 4GB model (e.g., `phi3:mini`), request at least `5Gi`. For running multiple models or larger ones like `mistral:7b` (a ~4.1GB Q4 model), `10Gi` or `16Gi` is safer. CPU requests should be at least `2` cores, limit `4` or more.
- **Persistent Volume**: A `volumeClaimTemplate` in the `StatefulSet` will dynamically provision a `PersistentVolume` for each replica to store models in `/root/.ollama`.
- **Model Pulling**: An `initContainer` is the best practice. It runs before the main container, pulls the required models, and then exits, ensuring models are available on pod startup.
- **Health Checks**:
    - **Liveness Probe**: `httpGet` on path `/` or `/api/tags`. If the server is unresponsive, K3s will restart the pod.
    - **Readiness Probe**: `httpGet` on path `/`. K3s will only send traffic to the pod once the API server is up.

### Model Management
#### CLI Reference
- `ollama pull <model>[:tag] [--insecure]`: Pull a model. Tag defaults to `latest`.
- `ollama list`: Show all local models.
- `ollama rm <model>[:tag]`: Remove a model.
- `ollama show <model>[:tag]`: Shows model details including parameters, template, and Modelfile.
- `ollama cp <source_model> <dest_model>`: Copy a model.
- `ollama create <name> -f <Modelfile_path>`: Create a new model from a Modelfile.

#### Model Selection (CPU-Only)

| Model Name | Size (Q4_K_M) | RAM Needed | Use Case | Notes |
| :--- | :--- | :--- | :--- | :--- |
| `phi3:mini` | ~2.3 GB | `4Gi` | Chat, Summarization, RAG | Best all-rounder for constrained environments. Excellent quality-to-size ratio. |
| `gemma2:2b` | ~1.6 GB | `3Gi` | Chatbots, Simple tasks | Extremely fast on CPU. Good alternative to Phi-3 for speed. |
| `llama3.2:3b`| ~2.1 GB | `3.5Gi` | Code Generation, Classification| Strong reasoning for its size, fast. |
| `mistral:7b` | ~4.1 GB | `6Gi` | High-quality Chat, Complex Summarization| Gold standard for 7B models. Requires more RAM. |
| **`nomic-embed-text`**| ~275 MB | `1Gi` | **RAG Embeddings** | **Recommended default embedding model.** 768 dimensions. |
| **`mxbai-embed-large`**| ~670 MB | `2Gi` | **High-quality Embeddings**| Slower but more accurate embeddings. 1024 dimensions. |

#### Quantization
Quantization reduces model size and memory usage at the cost of some precision.
- **`Q4_K_M`**: Recommended default. Good balance of size reduction and performance.
- **`Q5_K_M`**: Larger, slightly better quality than Q4. Use if you have spare RAM.
- **`Q8_0`**: Largest quantized size, closest to original quality. Use only if memory is not a concern.
- **`fp16`**: Unquantized. Not recommended for CPU inference due to huge memory and performance cost.

#### Running Multiple Models
By default, Ollama loads one model into memory at a time. To keep models "warm":
- **`keep_alive` parameter**: In the Modelfile or via `/api/generate`, `/api/chat` calls.
    - `keep_alive: "5m"`: Keeps the model loaded for 5 minutes after the last request.
    - `keep_alive: -1`: Keeps the model loaded indefinitely until another model is requested.
- **`OLLAMA_MAX_LOADED_MODELS` env var**: Set this to `2` or more to allow Ollama to keep multiple models in memory simultaneously, provided you have enough RAM.
- **`OLLAMA_NUM_PARALLEL` env var**: Number of parallel requests to process. Default is `1`. Increasing this requires significant RAM and CPU as it loads the model into memory multiple times. Not recommended for CPU-only setups unless you have a high core count and RAM.
- **`OLLAMA_NUM_THREADS` env var**: Number of CPU threads to use for inference. Defaults to the number of physical cores. Can be tuned if needed.

### Modelfile Syntax

```Modelfile
# Base model to build upon
FROM phi3:mini

# System-level instruction for the model
SYSTEM """
You are HelixBot, an expert AI assistant for Helix Stax, an IT consulting company.
Your goal is to provide accurate, concise, and helpful information on Kubernetes, Linux, Cloudflare, and automation.
Be professional and always base your answers on provided context when available.
Do not hallucinate. If you don't know the answer, say "I do not have enough information to answer that question."
"""

# Set model parameters
PARAMETER temperature 0.7   # Creativity vs. factuality. 0.7 is a good balance.
PARAMETER top_k 40          # Narrows the model's choices to the top 40 most likely tokens.
PARAMETER top_p 0.9         # Cumulative probability sampling. 0.9 is standard.
PARAMETER num_ctx 4096      # Context window size in tokens. Depends on base model.

# Define the chat template if needed (usually inherited from FROM)
TEMPLATE """
{{- if .System }}
<|system|>
{{ .System }}<|end|>
{{- end }}
<|user|>
{{ .Prompt }}<|end|>
<|assistant|>
"""

# (Optional) Apply a LoRA adapter
# ADAPTER ./my-lora-adapter.bin

# (Optional) License information
LICENSE "MIT"
```

### REST API Reference
Base URL: `http://ollama.default.svc.cluster.local:11434`

| Endpoint | Method | Description |
| :--- | :--- | :--- |
| `/api/generate`| `POST` | Single-turn, stateless completion. |
| `/api/chat` | `POST` | Multi-turn, stateful chat conversation. |
| `/api/embeddings`|`POST` | Generate vector embeddings for text. |
| `/api/tags` | `GET` | List all local models. Alias for `/api/list`. |
| `/api/show` | `POST` | Get model information. |
| `/api/pull` | `POST` | Pull a model from the registry. |
| `/api/delete` | `DELETE` | Delete a model. |

#### `/api/generate` Request Body
```json
{
  "model": "phi3:mini",
  "prompt": "What is Kubernetes?",
  "stream": false, // Set to true for streaming responses
  "system": "You are a helpful assistant.", // Override Modelfile SYSTEM
  "options": {
    "temperature": 0.8,
    "num_ctx": 2048
  }
}
```

#### `/api/chat` Request Body
```json
{
  "model": "helix-assistant",
  "messages": [
    { "role": "user", "content": "What is K3s?" },
    { "role": "assistant", "content": "K3s is a lightweight Kubernetes distribution..." },
    { "role": "user", "content": "How is it different from K8s?" }
  ],
  "stream": false
}
```

#### `/api/embeddings` Request Body
```json
{
  "model": "nomic-embed-text",
  "prompt": "This is the text to be embedded."
}
```
**Response**: `{"embedding": [0.123, 0.456, ...]}` (Array of 768 floats for `nomic-embed-text`).

### Security & Logging
- **Authentication**: Ollama has no built-in auth. It is **critical** that it is not exposed publicly. The K3s `Service` of type `ClusterIP` ensures it is only reachable within the cluster.
- **Metrics**: Ollama exposes Prometheus metrics at `/metrics`. A `ServiceMonitor` or pod annotation can be used to scrape them.
- **Logging**: Logs are sent to `stdout`/`stderr` and can be configured with environment variables:
    - `OLLAMA_DEBUG=1`: Enable debug logging.
    - `OLLAMA_LOG_FILE=/path/to/log`: Write logs to a file (not recommended in K3s; use stdout).

---

## ## examples.md Content
Copy-paste-ready manifests and configurations for the Helix Stax environment.

### 1. K3s StatefulSet and Service (`ollama.yaml`)
This manifest creates a StatefulSet with a persistent volume for models, an initContainer to pre-pull models, and a ClusterIP service for internal access.

```yaml
# ollama.yaml
apiVersion: v1
kind: Service
metadata:
  name: ollama
  namespace: default # Or a dedicated 'ai' namespace
spec:
  selector:
    app: ollama
  ports:
    - protocol: TCP
      port: 11434
      targetPort: 11434
  type: ClusterIP # Internal only
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: ollama
  namespace: default
spec:
  serviceName: "ollama"
  replicas: 1
  selector:
    matchLabels:
      app: ollama
  template:
    metadata:
      labels:
        app: ollama
      annotations:
        prometheus.io/scrape: 'true'
        prometheus.io/port: '11434'
        prometheus.io/path: '/metrics'
    spec:
      initContainers:
      - name: pull-models
        image: docker.io/ollama/ollama:latest  # Pin version in production (e.g., ollama/ollama:0.3.0)
        command: ["/bin/sh", "-c"]
        args:
          - |
            ollama pull phi3:mini
            ollama pull nomic-embed-text
            ollama pull mxbai-embed-large
        volumeMounts:
        - name: ollama-models
          mountPath: /root/.ollama
      containers:
      - name: ollama
        image: docker.io/ollama/ollama:latest  # Pin version in production (e.g., ollama/ollama:0.3.0)
        ports:
        - containerPort: 11434
          name: http
        env:
        - name: OLLAMA_HOST
          value: "0.0.0.0"
        - name: OLLAMA_KEEP_ALIVE
          value: "10m" # Keep models warm for 10 minutes
        - name: OLLAMA_MAX_LOADED_MODELS
          value: "2" # Allow two models in memory if RAM permits
        resources:
          requests:
            memory: "8Gi"
            cpu: "2"
          limits:
            memory: "16Gi"
            cpu: "4"
        volumeMounts:
        - name: ollama-models
          mountPath: /root/.ollama
        livenessProbe:
          httpGet:
            path: /
            port: 11434
          initialDelaySeconds: 15
          periodSeconds: 20
        readinessProbe:
          httpGet:
            path: /
            port: 11434
          initialDelaySeconds: 5
          periodSeconds: 10
  volumeClaimTemplates:
  - metadata:
      name: ollama-models
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: "longhorn" # Or your cluster's default StorageClass
      resources:
        requests:
          storage: 50Gi # Adjust based on number of models
```
**Deploy**: `kubectl apply -f ollama.yaml`

### 2. Custom Modelfile for Helix Stax (`HelixModelfile`)
This Modelfile creates a persona-driven model for internal use.

```Modelfile
FROM phi3:mini

SYSTEM """
You are HelixBot, a specialized AI assistant for Helix Stax. Helix Stax is an IT consulting firm specializing in Kubernetes, cloud-native infrastructure, and automation for small to medium businesses.
Your primary directive is to provide technically accurate, concise answers.
When asked about infrastructure, assume the context of the Helix Stax stack: K3s on Hetzner, Traefik, Zitadel OIDC, CloudNativePG, and n8n.
The internal domain is helixstax.net. The control plane is 178.156.233.12. A worker node is 5.78.145.30.
If you are provided with context from a RAG pipeline (documents or web search), prioritize that information above all else.
If you cannot answer from the provided context or your internal knowledge, state "I do not know" instead of guessing.
"""

PARAMETER temperature 0.6
PARAMETER num_ctx 4096
```
**Create the custom model**:
1.  `kubectl cp ./HelixModelfile ollama-0:/app/HelixModelfile -c ollama`
2.  `kubectl exec -it ollama-0 -c ollama -- ollama create helix-assistant -f /app/HelixModelfile`
3.  `kubectl exec -it ollama-0 -c ollama -- ollama list` (Verify `helix-assistant` exists)

### 3. n8n HTTP Request Node for Summarization
This calls Ollama directly to summarize text.

**Node**: `HTTP Request`
- **URL**: `http://ollama.default.svc.cluster.local:11434/api/generate`
- **Method**: `POST`
- **Send Body**: `true`
- **Body Content Type**: `JSON`
- **Body**:
```json
{
  "model": "phi3:mini",
  "prompt": "Summarize the following text in three bullet points:\n\n{{ $json.textToSummarize }}",
  "stream": false
}
```
- **Response Format**: `JSON`
- **To get the content**: `{{ $json.body.response }}`

### 4. n8n HTTP Request Node for Embeddings
This calls Ollama to get a vector embedding for a chunk of text.

**Node**: `HTTP Request`
- **URL**: `http://ollama.default.svc.cluster.local:11434/api/embeddings`
- **Method**: `POST`
- **Send Body**: `true`
- **Body Content Type**: `JSON`
- **Body**:
```json
{
  "model": "nomic-embed-text",
  "prompt": "{{ $json.textChunk }}"
}
```
- **Response Format**: `JSON`
- **To get the vector**: `{{ JSON.stringify($json.body.embedding) }}` (This can be passed to a PostgreSQL node for `INSERT`).

***

# Open WebUI

## ## SKILL.md Content
Core reference for daily operations and troubleshooting.

### Common UI Tasks
- **Login**: Navigate to `https://open-webui.helixstax.net`. Authenticate via Zitadel.
- **Select Model**: Use the dropdown menu at the top of the chat interface (`@` symbol).
- **Upload Document for RAG**:
    1. In a chat, click the `#` symbol next to the model selector.
    2. Click "Add a document".
    3. Choose "Upload a file".
    4. Select the document. Open WebUI will chunk, embed, and store it.
- **Use RAG**: After uploading a doc, ensure the `#` dropdown shows the document name. Ask a question related to the document.
- **Use Web Search**:
    1. In a chat, click the "Search on the web" toggle (globe icon).
    2. Type your query. Open WebUI will query SearXNG and inject results into the context.
- **Generate API Key**: Go to `Settings` > `Account` > `API Keys` section. Generate a key for `n8n`.

### Troubleshooting Decision Tree

| Symptom | Probable Cause | Fix |
| :--- | :--- | :--- |
| **502 Bad Gateway at `open-webui.helixstax.net`** | 1. `open-webui` pod is down. <br> 2. Traefik IngressRoute is misconfigured. | 1. `kubectl get pods -l app.kubernetes.io/name=open-webui`. Check logs. <br> 2. `kubectl describe ingressroute open-webui` and check service name/port. |
| **OIDC Login Fails / Redirect URI Mismatch** | 1. Redirect URI in Zitadel is incorrect. <br> 2. OIDC client ID/secret is wrong. | 1. In Zitadel, ensure the application's Redirect URI is exactly `https://open-webui.helixstax.net/oauth/callback`. <br> 2. Double-check `OAUTH_CLIENT_ID` and `OAUTH_CLIENT_SECRET` in the `open-webui` secret. |
| **"Ollama is not running" error in UI** | `OLLAMA_BASE_URL` is wrong or Ollama pod is down. | Ensure `OLLAMA_BASE_URL` in `values.yaml` is `http://ollama.default.svc.cluster.local:11434` and the Ollama pod is running. |
| **Chat history is lost after pod restart** | PostgreSQL connection failed, or persistence is disabled. | 1. Check `open-webui` logs for DB connection errors. <br> 2. Verify `DATABASE_URL` is correct. <br> 3. Verify Helm `persistence.enabled=true`. |
| **RAG search finds no documents** | 1. `pgvector` extension not enabled. <br> 2. Embedding model mismatch. <br> 3. Document failed to ingest. | 1. In CloudNativePG, ensure `pgvector` is in `shared_preload_libraries`. <br> 2. Ensure model used for embedding matches model selected in UI settings. <br> 3. Check logs during doc upload. |

---

## ## reference.md Content
Deep specifications for deployment, configuration, and integration.

### K3s Deployment (Helm)
The official Helm chart is the recommended method.

- **Chart**: `open-webui/open-webui`
- **Repository**: `https://helm.openwebui.com/`
- **Key `values.yaml` Overrides**:
    - `ollama.baseUrl`: Points to the internal Ollama service.
    - `postgresql.enabled=false`: Disable the chart's built-in Postgres.
    - `extraEnvs`: Used to configure the external CloudNativePG database, OIDC, and other settings.
    - `ingress.enabled=true`: To create a standard Kubernetes Ingress (we will disable and use Traefik `IngressRoute` instead).
    - `persistence.enabled=true`: To store uploaded files and other data.

### Environment Variable Reference (via `extraEnvs`)

| Variable | Description | Example Value |
| :--- | :--- | :--- |
| **`OLLAMA_BASE_URL`** | **Required.** URL of the Ollama service. | `http://ollama.default.svc.cluster.local:11434` |
| **`DATABASE_URL`** | **Required.** Connection string for PostgreSQL. | `postgresql://user:password@host:port/dbname` |
| `ENABLE_OAUTH` | **Required.** Set to `true` to enable OIDC. | `"true"` |
| `OAUTH_CLIENT_ID` | **Required.** Zitadel application client ID. | From Zitadel console |
| `OAUTH_CLIENT_SECRET`| **Required.** Zitadel application client secret. | From Zitadel console |
| `OAUTH_AUTH_URL` | **Required.** Zitadel authorization endpoint. | `https://zitadel.helixstax.net/oauth/v2/authorize` |
| `OAUTH_TOKEN_URL` | **Required.** Zitadel token endpoint. | `https://zitadel.helixstax.net/oauth/v2/token` |
| `OAUTH_PROFILE_URL` | **Required.** Zitadel userinfo endpoint. | `https://zitadel.helixstax.net/oidc/v1/userinfo` |
| `OAUTH_LOGOUT_URL` | Optional. Zitadel logout URL. | `https://zitadel.helixstax.net/oidc/v1/end_session` |
| `OAUTH_SCOPE` | **Required.** OIDC scopes. | `"openid profile email"` |
| `WEBUI_SECRET_KEY` | Secret key for signing sessions. A 32-byte random string. | Generate with `openssl rand -hex 32` |
| `ENABLE_SIGNUP` | Allow open user registration. Set to `false` with OIDC. | `"false"` |
| `DEFAULT_MODELS` | Default models to show in the UI. | `helix-assistant,phi3:mini` |
| `WEB_SEARCH_ENGINE` | Set web search provider. | `searxng` |
| `SEARXNG_BASE_URL` | **Required for web search.** URL of SearXNG. | `http://searxng.default.svc.cluster.local:8080` |

### RAG Pipeline Deep Dive
1.  **Upload**: User uploads a file (PDF, TXT, MD, DOCX) via the UI.
2.  **Storage**: The raw file is saved to the Persistent Volume at `/app/backend/data/uploads`.
3.  **Chunking**: The document is split into smaller text chunks. Configurable in `Admin Settings` > `RAG`.
    - **Chunk Size**: Recommended: `512` to `1024` characters.
    - **Chunk Overlap**: Recommended: `50` to `100` characters. Helps maintain context between chunks.
4.  **Embedding**: Each chunk is sent to Ollama's `/api/embeddings` endpoint using the configured embedding model (e.g., `nomic-embed-text`).
5.  **Storage (pgvector)**: The returned vector is stored in a `documents` table in PostgreSQL, linked to the original document and chunk content. Open WebUI uses the `pgvector` extension for this.
6.  **Retrieval**:
    - User sends a query with a document selected (`#` tag).
    - The query text is sent to the *same* `/api/embeddings` endpoint.
    - A similarity search (default: **cosine similarity**) is performed in `pgvector` to find the top-k document chunks closest to the query vector.
    - `SELECT ... FROM documents ORDER BY embedding <=> query_vector LIMIT 5;`
7.  **Synthesis**: The retrieved chunks are prepended to the user's query as context in the prompt sent to the LLM (e.g., `phi3:mini`).
8.  **Response**: The LLM generates a response based on the provided context and its own knowledge.

**Hybrid Search**: As of late 2024, Open WebUI does not have built-in support for hybrid (vector + keyword) search. It relies purely on vector similarity.

### API Access (OpenAI-Compatible)
Open WebUI exposes an OpenAI-compatible API, making it a drop-in replacement for many tools.
- **Base URL**: `https://open-webui.helixstax.net/v1`
- **Authentication**: `Authorization: Bearer <API_KEY>` (Generate key in UI Settings)
- **Endpoint**: `/chat/completions`

**When to use Open WebUI API vs. Ollama API:**
- **Use Ollama API (`/api/generate`)** for simple, raw text generation, classification, or summarization where chat history and RAG are not needed (e.g., a simple n8n summarizer workflow).
- **Use Open WebUI API (`/v1/chat/completions`)** when you need to leverage the RAG pipeline, use pre-configured model presets, or interact with an existing chat conversation history. It acts as a smart proxy and orchestrator.

---

## ## examples.md Content
Copy-paste-ready manifests and configurations for the Helix Stax environment.

### 1. Secret for Open WebUI (`open-webui-secret.yaml`)
Create this secret before deploying the Helm chart.

```yaml
# open-webui-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: open-webui-secret
  namespace: default
type: Opaque
stringData:
  # Generate with: openssl rand -hex 32
  WEBUI_SECRET_KEY: "your-super-strong-random-32-byte-hex-string-goes-here"
  
  # From Zitadel Application
  OAUTH_CLIENT_ID: "your-zitadel-client-id"
  OAUTH_CLIENT_SECRET: "your-zitadel-client-secret"

  # From CloudNativePG cluster secret
  DATABASE_URL: "postgresql://openwebui-user:YOUR_POSTGRES_PASSWORD@pg-cluster-rw.default.svc.cluster.local:5432/openwebui_db"
```
**Deploy**: `kubectl apply -f open-webui-secret.yaml`

### 2. Helm Values (`open-webui-values.yaml`)
This `values.yaml` file configures the Helm chart for the Helix Stax stack.

```yaml
# open-webui-values.yaml
image:
  repository: ghcr.io/open-webui/open-webui
  tag: main # Or a specific version like 0.4.1

# Disable the chart's ingress, we'll use a manual Traefik IngressRoute
ingress:
  enabled: false

# Disable the chart's postgresql, we use CloudNativePG
postgresql:
  enabled: false

# Enable persistence for uploads and data
persistence:
  enabled: true
  storageClass: "longhorn"
  size: 10Gi

# Configure environment variables
extraEnvs:
  # Connect to our internal Ollama service
  - name: OLLAMA_BASE_URL
    value: "http://ollama.default.svc.cluster.local:11434"
  
  # Connect to external PostgreSQL (from the secret)
  - name: DATABASE_URL
    valueFrom:
      secretKeyRef:
        name: open-webui-secret
        key: DATABASE_URL

  # Enable OIDC/OAuth
  - name: ENABLE_OAUTH
    value: "true"
  - name: ENABLE_SIGNUP
    value: "false" # Users must come from Zitadel
  
  # OIDC Client ID (from the secret)
  - name: OAUTH_CLIENT_ID
    valueFrom:
      secretKeyRef:
        name: open-webui-secret
        key: OAUTH_CLIENT_ID
        
  # OIDC Client Secret (from the secret)
  - name: OAUTH_CLIENT_SECRET
    valueFrom:
      secretKeyRef:
        name: open-webui-secret
        key: OAUTH_CLIENT_SECRET

  # Zitadel endpoints
  - name: OAUTH_AUTH_URL
    value: "https://zitadel.helixstax.net/oauth/v2/authorize"
  - name: OAUTH_TOKEN_URL
    value: "https://zitadel.helixstax.net/oauth/v2/token"
  - name: OAUTH_PROFILE_URL
    value: "https://zitadel.helixstax.net/oidc/v1/userinfo"

  # OIDC Scopes
  - name: OAUTH_SCOPE
    value: "openid profile email"

  # WebUI Secret Key (from the secret)
  - name: WEBUI_SECRET_KEY
    valueFrom:
      secretKeyRef:
        name: open-webui-secret
        key: WEBUI_SECRET_KEY

  # SearXNG Integration
  - name: WEB_SEARCH_ENGINE
    value: "searxng"
  - name: SEARXNG_BASE_URL
    value: "http://searxng.default.svc.cluster.local:8080"
    
  # RAG default embedding model
  - name: DEFAULT_EMBEDDING_MODEL
    value: "nomic-embed-text"
```
**Deploy/Upgrade with Helm**:
```sh
helm repo add open-webui https://helm.openwebui.com/
helm repo update
helm upgrade --install open-webui open-webui/open-webui -f open-webui-values.yaml -n default
```

### 3. Traefik IngressRoute (`open-webui-ingressroute.yaml`)
This exposes Open WebUI securely at `open-webui.helixstax.net` with TLS.

```yaml
# open-webui-ingressroute.yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: open-webui
  namespace: default
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`open-webui.helixstax.net`)
      kind: Rule
      services:
        - name: open-webui # This must match the service name created by the Helm chart
          port: 8080
  tls:
    secretName: open-webui-origin-ca-tls # Cloudflare Origin CA cert
```
**Deploy**: `kubectl apply -f open-webui-ingressroute.yaml`

***

# SearXNG

## ## SKILL.md Content
Core reference for daily operations and troubleshooting.

### Common Tasks
- **Check Pod Status**: `kubectl get pod -l app=searxng`
- **View Logs**: `kubectl logs -f <searxng-pod-name>` (useful for seeing engine failures)
- **Modify Configuration**:
    1. `kubectl edit configmap searxng-settings`
    2. Change the `settings.yml` content.
    3. `kubectl delete pod -l app=searxng` to apply the changes.
- **Test API from within cluster**:
    ```sh
    kubectl run -it --rm --image=curlimages/curl debug -- sh
    # Inside the debug pod:
    curl "http://searxng.default.svc.cluster.local:8080/search?q=kubernetes&format=json"
    ```

### Troubleshooting Decision Tree

| Symptom | Probable Cause | Fix |
| :--- | :--- | :--- |
| **Open WebUI reports "web search is not available"** | 1. `SEARXNG_BASE_URL` is wrong in WebUI. <br> 2. SearXNG pod is down. | 1. Verify `SEARXNG_BASE_URL` env var is `http://searxng.default.svc.cluster.local:8080`. <br> 2. Check pod status with `kubectl get pod -l app=searxng`. |
| **Search results are empty or mostly errors** | 1. Public search engines are rate-limiting the server IP. <br> 2. Engine `timeout` is too low. | 1. This is expected. SearXNG automatically bans failing engines for a short time. <br> 2. In `settings.yml`, increase `ban_time_on_fail` and `request_timeout`. Enable more diverse engines. |
| **API returns HTML instead of JSON** | The `format=json` query parameter is missing. | Append `&format=json` to the API request URL. |
| **Pod fails to start in a loop** | `secret_key` in `settings.yml` is missing or invalid. | Ensure `secret_key` is set in the ConfigMap and is a long, random string. |

---

## ## reference.md Content
Deep specifications for deployment, configuration, and API usage.

### K3s Deployment (Deployment)
A stateless `Deployment` is suitable for SearXNG. All configuration is managed via a `ConfigMap` and a `Secret`.

- **Manifests**: Use raw K8s manifests for a `Deployment`, `Service`, `ConfigMap`, and `Secret`.
- **ConfigMap for `settings.yml`**: This is the core of SearXNG. Mount it as a file into the pod.
- **Secret for `secret_key`**: The `secret_key` should be stored in a K8s `Secret` and injected as an environment variable to avoid hardcoding it in the `ConfigMap`.
- **Resource Requirements**: SearXNG is very lightweight. `requests: {cpu: "100m", memory: "128Mi"}`, `limits: {cpu: "500m", memory: "256Mi"}` is a good starting point.
- **Stateless**: No `PersistentVolume` is needed.

### Configuration (`settings.yml`) Reference

**general:**
- `instance_name`: "Helix Stax Search"
- `contact_url`: "https://helixstax.com"
- `enable_metrics`: `true` (for Prometheus)

**search:**
- `safe_search`: `1` (0: off, 1: moderate, 2: strict)
- `autocomplete`: `""` (Disable for API-only use)
- `default_lang`: `"en"`
- `ban_time_on_fail`: `300` (Seconds to ban a failing engine)
- `max_ban_time_on_fail`: `3600` (Max ban time)

**server:**
- `secret_key`: **(CRITICAL)** A long random string.
- `bind_address`: `"0.0.0.0"`
- `port`: `8080`
- `image_proxy`: `true` (Privacy-enhancing, but increases bandwidth)
- `method`: `"POST"` (Slightly better privacy than GET)

**outgoing:**
- `request_timeout`: `3.0` (Seconds)
- `useragent`: A generic user agent string.
- `pool_connections`: `100`

**engines:**
This is a list of dictionaries defining active engines.

```yaml
- name: google
  engine: google
  shortcut: g
  weight: 200 # Higher weight = prioritized higher
  timeout: 2.5
- name: duckduckgo
  engine: duckduckgo
  shortcut: ddg
  weight: 150
- name: brave
  engine: brave
  shortcut: br
  weight: 150
- name: github
  engine: github
  shortcut: gh
  categories: [code]
  weight: 100
- name: stackoverflow
  engine: stackoverflow
  shortcut: so
  categories: [it, code]
  weight: 100
- name: wikipedia
  engine: wikipedia
  shortcut: wp
  categories: [general]
  weight: 50
```

**Recommended engines for IT consulting:**
- **Web**: `google`, `bing`, `duckduckgo`, `brave`
- **Code**: `github`, `gitlab`, `stackoverflow`
- **IT / Science**: `wikipedia`, `arxiv`, `npm`
- **Security**: Consider adding `cve`, `shodan` if relevant, but be mindful of API terms.
- **Disable**: `kickass`, `piratebay`, most `shopping` and `social media` engines to reduce noise.

### API Access
- **Endpoint**: `/search`
- **Output Format**: `?format=json`
- **Query Parameters**:
    - `q`: The search query.
    - `categories`: Comma-separated list (e.g., `code,it`).
    - `engines`: Comma-separated list to query only specific engines (e.g., `google,github`).
    - `pageno`: Page number for pagination.
    - `time_range`: `day`, `week`, `month`, `year`.
    - `safesearch`: `0`, `1`, `2`.
- **API-Only Mode**: There is no official "API-only" mode, but by only exposing it internally and not advertising the URL, it functions as an API. You can heavily customize the UI settings in `settings.yml` to be minimal if anyone does access it via browser.

---

## ## examples.md Content
Copy-paste-ready manifests and configurations for the Helix Stax environment.

### 1. SearXNG Secret (`searxng-secret.yaml`)
```yaml
# searxng-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: searxng-secret
  namespace: default
type: Opaque
stringData:
  # Generate with: head -c 32 /dev/urandom | base64
  secret-key: "your-long-random-base64-encoded-secret-key"
```
**Deploy**: `kubectl apply -f searxng-secret.yaml`

### 2. SearXNG ConfigMap & Deployment (`searxng.yaml`)
This manifest contains the `ConfigMap` with `settings.yml`, the `Deployment`, and the `Service`.

```yaml
# searxng.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: searxng-settings
  namespace: default
data:
  settings.yml: |
    server:
      bind_address: "0.0.0.0"
      port: 8080
      secret_key: "{{ env.SECRET_KEY }}" # This will be replaced by the pod
      image_proxy: true
      method: "POST"

    general:
      instance_name: "Helix Stax Internal Search"
      enable_metrics: true

    search:
      autocomplete: ""
      safe_search: 1
      default_lang: "en"
      ban_time_on_fail: 600
      max_ban_time_on_fail: 7200

    outgoing:
      request_timeout: 4.0
      useragent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36"

    ui:
      static_use_hash: true
      query_in_title: false
      infinite_scroll: true

    engines:
      # General Web
      - name: google
        engine: google
        shortcut: g
        weight: 100
        categories: [general, web]
        timeout: 3.5
      - name: duckduckgo
        engine: duckduckgo
        shortcut: ddg
        weight: 80
        categories: [general, web]
      - name: brave
        engine: brave
        shortcut: br
        weight: 80
        categories: [general, web]
      # IT & Code
      - name: github
        engine: github
        shortcut: gh
        categories: [code]
        weight: 120
      - name: stackoverflow
        engine: stackoverflow
        shortcut: so
        categories: [it, code]
        weight: 110
      - name: wikipedia
        engine: wikipedia
        shortcut: wp
        categories: [general]

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: searxng
  namespace: default
  labels:
    app: searxng
spec:
  replicas: 1
  selector:
    matchLabels:
      app: searxng
  template:
    metadata:
      labels:
        app: searxng
    spec:
      containers:
      - name: searxng
        image: docker.io/searxng/searxng:latest
        env:
        - name: SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: searxng-secret
              key: secret-key
        - name: SEARXNG_SETTINGS_PATH
          value: /etc/searxng/settings.yml
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: settings
          mountPath: /etc/searxng
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 256Mi
      volumes:
      - name: settings
        configMap:
          name: searxng-settings
---
apiVersion: v1
kind: Service
metadata:
  name: searxng
  namespace: default
spec:
  selector:
    app: searxng
  ports:
  - name: http
    port: 8080
    targetPort: 8080
```
**Deploy**: `kubectl apply -f searxng.yaml`

### 3. n8n HTTP Request Node for SearXNG
This workflow node queries SearXNG for web results.

**Node**: `HTTP Request`
- **URL**: `http://searxng.default.svc.cluster.local:8080/search`
- **Method**: `GET`
- **Send Query Parameters**: `true`
- **Query Parameters**:
    - `q`: `{{ $json.query }}`
    - `format`: `json`
    - `categories`: `general,it,code`
- **Response Format**: `JSON`
- **To get results**: `{{ $json.body.results }}` (This will be an array of result objects).

***

# Cross-Cutting, Best Practices & Decisions

This section consolidates information from the above tools into workflows and high-level guidance.

## ## SKILL.md Content
### Embeddings Pipeline Flow
`Document -> n8n Webhook -> Chunking -> Ollama Embeddings -> CloudNativePG (pgvector) -> Open WebUI RAG`

**n8n Workflow Steps:**
1.  **Webhook Trigger**: Receives a file or text.
2.  **Code Node (JavaScript)**: To chunk the text into an array of strings.
3.  **Split in Batches Node**: To iterate over each chunk.
4.  **HTTP Request Node (Ollama)**: Calls `/api/embeddings` with the chunk.
    - Model: `nomic-embed-text`
5.  **PostgreSQL Node**: Inserts the chunk and its embedding into the `documents` table.
    - **Query**: `INSERT INTO documents (content, embedding) VALUES ($1, $2)`
    - **Parameters**: `[{{ $json.textChunk }}, {{ JSON.stringify($json.embeddingVector) }}]`

### n8n AI Workflow Patterns
- **Summarization**: `Webhook -> HTTP Request (Ollama /api/generate) -> Chat/Email Node`
- **RAG-Augmented Query**: `Webhook -> HTTP Request (SearXNG) -> Code Node (Format results) -> HTTP Request (Ollama /api/generate with context) -> Response`
- **Document Ingestion**: The embedding pipeline described above.

---

## ## reference.md Content
### pgvector Integration Details
- **Open WebUI Schema**: Open WebUI automatically creates tables when it first connects to the database. The key table is `documents`, which contains columns like `collection_name`, `name` (filename), `title`, `content` (the chunk), and `embedding` (type `vector(DIM)`).
- **Embedding Dimensions**:
    - **`nomic-embed-text`**: 768 dimensions. The `embedding` column must be `vector(768)`.
    - **`mxbai-embed-large`**: 1024 dimensions. The `embedding` column must be `vector(1024)`.
    - **CRITICAL**: The dimension of the model used to create embeddings *must match* the dimension of the vector column in PostgreSQL. A mismatch will cause insertion or query errors.
- **Similarity Search**: Open WebUI uses **cosine distance** (`<=>` operator in pgvector) for similarity search, which is effective for normalized embeddings like those from `nomic-embed-text`.
- **Indexing**: For small-scale use (<1M vectors), a sequential scan is acceptable. For better performance, an index is required.
    - **IVFFlat**: Good for static data. Fast build time.
    - **HNSW (Hierarchical Navigable Small Worlds)**: **Recommended**. Better for data that is frequently updated (like adding new documents). Offers excellent query speed at the cost of higher build time and memory usage.
    - **Create Index Command**: `CREATE INDEX ON documents USING hnsw (embedding vector_cosine_ops);` (Execute this on your `openwebui_db` after the table is created).

### n8n Community Nodes
- **`n8n-nodes-langchain`**: **Yes, this is compatible.** You can configure the LangChain nodes to use a custom LLM provider by pointing it to the Ollama API endpoint (`http://ollama.default.svc.cluster.local:11434`). This provides a higher-level abstraction than raw HTTP calls.
- **Native Ollama Node**: As of late 2024, n8n has a native Ollama node. This is the **preferred method** as it simplifies configuration. You simply provide the base URL and select the action (Generate, Chat, Embed).

---

## ## Decision Matrix & Best Practices
### Top 10 Best Practices
1.  **Isolate AI Services**: Deploy Ollama and SearXNG as `ClusterIP` services. Never expose them directly to the internet. Expose Open WebUI via Traefik with OIDC authentication.
2.  **Use StatefulSets for Ollama**: Ensure model persistence across restarts using a `StatefulSet` and a `PersistentVolumeClaim`.
3.  **Pre-pull Models with initContainers**: Avoid slow cold starts on pod creation by pulling required models in an `initContainer`.
4.  **Set Resource Limits**: Define realistic memory and CPU requests/limits for Ollama. Memory is the most critical resource. `Model Size + 1GB` is a safe minimum request.
5.  **Use a Consistent Embedding Model**: Choose one embedding model (e.g., `nomic-embed-text`) for your RAG pipeline and stick with it. If you change it, you must re-embed all your documents.
6.  **Manage Config with K8s Primitives**: Use `ConfigMaps` for `settings.yml` (SearXNG) and `Secrets` for all sensitive data (API keys, passwords, OIDC secrets).
7.  **Use Helm for Complex Apps**: Use the official `open-webui` Helm chart and manage customizations via a version-controlled `values.yaml` file.
8.  **Automate with Cluster-Internal URLs**: When configuring n8n or Open WebUI to talk to other services, always use the K3s DNS names (e.g., `ollama.default.svc.cluster.local:11434`). It's faster and more secure.
9.  **Index pgvector**: For any serious RAG usage, create an `HNSW` index on your `embedding` column to ensure fast query performance.
10. **Monitor Everything**: Scrape Prometheus metrics from Ollama and enable logging. Watch for OOM errors in Ollama and rate-limiting errors in SearXNG.

### Decision Matrix

| If you need to... | Use... | Because... |
| :--- | :--- | :--- |
| Generate simple text without memory | Ollama `/api/generate` | It's stateless, fast, and direct. Ideal for one-off tasks like summarization. |
| Have a conversation or use RAG | Open WebUI API (`/v1/chat/completions`) | It manages chat history, document context injection, and model presets for you. |
| Get the highest quality output | `mistral:7b` (or larger) | It has better reasoning, but requires the most RAM. |
| Get the fastest response | `gemma2:2b` or `phi3:mini` | They are small, highly optimized, and perform well on CPU. |
| Embed text for RAG | `nomic-embed-text` | It's small, fast, and the top-performing open model in its size class. |
| Ingest documents for RAG | n8n workflow or Open WebUI upload | n8n offers more control and automation; the UI is simpler for manual one-offs. |
| Authenticate users | Zitadel OIDC with Open WebUI | It provides centralized, secure, SSO-based access control. |
| Get live web context | SearXNG integrated with Open WebUI | It provides real-time information to the LLM, reducing hallucinations on current events. |

### Common Pitfalls & Anti-Patterns
- **Critical:** Exposing Ollama's port `11434` publicly. This is a massive security risk, as there is no authentication.
- **Critical:** Mismatched embedding dimensions. Storing 768-dim vectors then querying with a 1024-dim model (or vice-versa) will fail silently or with cryptic database errors.
- **Severe:** Not using a PVC for Ollama. All models (GBs of data) will be re-downloaded every time the pod restarts, wasting time and bandwidth.
- **Moderate:** Setting Ollama memory limits too low. This causes the pod to be `OOMKilled` by Kubernetes whenever a large model is loaded. Check `kubectl describe pod` for the reason.
- **Moderate:** Using the default SQLite database for Open WebUI in production. It's not scalable, not suitable for multiple replicas, and makes backups difficult. Always use CloudNativePG.
- **Low:** Enabling too many noisy SearXNG engines. This increases the chance of rate-limiting and returns irrelevant results. Curate your engine list.
- **Performance Anti-Pattern:** Not setting `keep_alive` or `OLLAMA_MAX_LOADED_MODELS`. This forces Ollama to constantly load and unload models from disk into RAM, adding 15-30s of latency to the first request for any model.
