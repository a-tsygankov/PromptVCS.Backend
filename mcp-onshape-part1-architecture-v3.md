# MCP × Onshape: Part 1 — Architecture Deep Dive (MCP‑first, REST‑backed) — v3

**Positioning:** MCP is the primary orchestration layer (tools/resources/prompts, progress, streaming). **Onshape REST** is the data plane for CAD/PLM. The MCP server wraps Onshape operations and exposes them as first‑class MCP capabilities that LLMs, IDEs, and agents can discover and use.

---

## A) Agent‑Oriented MCP Functionality (LLM / IDE view)

### A1. Capability discovery → Onshape scope
MCP discovery (`tools/list`, `resources/list`, `prompts/list`) surfaces all available operations.  
Map to Onshape concepts: Documents, Workspaces, Versions, Elements, BOM, Release states.

Key references:  
- Onshape REST Intro: https://onshape-public.github.io/docs/api-intro/  
- Versions/Branching Primer: https://cad.onshape.com/help/Content/Primer/versions.htm

**Discovery surface (examples):**
- `os.listDocuments`, `os.listWorkspaces`, `os.listVersions`, `os.listElements`
- `os.getAssemblyGraph`, `os.getBOM`, `os.getReleaseState`
- `os.export`, `os.createVersion`, `os.submitRelease`

---

### A2. Tool calls with Progress & Streaming
MCP uses JSON‑RPC with **progress notifications** over **stdio** or **Streamable HTTP + SSE**.  
Onshape’s long‑running jobs (e.g., translation/export) fit this perfectly.

References:  
- MCP Transports: https://modelcontextprotocol.io/docs/concepts/transports  
- Onshape Translation API: https://onshape-public.github.io/docs/api-adv/translation/  

Benefits for slow models: non‑blocking, observable progress, resumable.

---

### A3. Resources (Files, Datasets)
Expose Onshape artifacts as MCP **resources** (URLs or handles).  
Attach deterministic scope → use **Version**, not Workspace.

References:  
- Export Overview: https://cad.onshape.com/help/Content/exporting-files.htm  
- Versions Primer: https://cad.onshape.com/help/Content/Primer/versions.htm  

---

### A4. Prompts (Guided Interactions)
Predefined **prompts** help navigate document hierarchy and workflows.  
Use for selection (Doc → Version → Element), consent dialogs, and release readiness.

Reference: Release Management  
https://cad.onshape.com/help/Content/release_management.htm

---

### A5. Auth clarity
- OAuth2 for user apps (required for App Store)  
- API Keys for automation
- Expose mode & scopes as readable resource

References:  
- OAuth2 Guide: https://onshape-public.github.io/docs/auth/  
- API Keys: https://onshape-public.github.io/docs/auth/apikeys/

---

### A6. Agent Capability Matrix

| MCP Tool | Onshape Area | Example |
|-----------|--------------|----------|
| `os.listDocuments` | Search | Find design docs |
| `os.listWorkspaces` | Branches | Choose working branch |
| `os.listVersions` | Snapshots | Pick stable revision |
| `os.listElements` | Tabs | Get Assemblies/Drawings |
| `os.getAssemblyGraph` | Structure | Explore hierarchy |
| `os.getBOM` | BOM API | Compare released vs working |
| `os.export` | Translation | Export STEP/GLTF/PDF |
| `os.submitRelease` | Workflow | Submit revision for approval |

---

### A7. Best Practices for Slow Models
- Expect async jobs & progress streams  
- Use capability discovery, not guesses  
- Resume via jobId/resources  
- Prefer Version IDs for artifacts

---

## B) System Integration Architecture (Developer / Server View)

### B1. Topology

```
MCP Client (LLM/IDE)
 └── stdio / Streamable HTTP (SSE)
      └── MCP Server
            ├─ Tools Layer (JSON‑RPC)
            │   └─ Onshape REST Adapter (OAuth2/API Key)
            ├─ Job Queue & Progress Bus
            ├─ Resource Store (Artifacts, Pages)
            └─ Webhook Receiver (Event Fan‑In)
```

References:  
- MCP Architecture: https://modelcontextprotocol.io/docs/concepts/architecture  
- Onshape Webhooks: https://onshape-public.github.io/docs/app-dev/webhook/

---

### B2. Tool Mapping

| MCP Tool | REST Endpoint | Notes |
|-----------|----------------|-------|
| `os.listDocuments` | /api/documents | List user/company docs |
| `os.listWorkspaces` | /api/documents/{id}/workspaces | Active branches |
| `os.listVersions` | /api/documents/{id}/versions | Immutable |
| `os.listElements` | /api/documents/{id}/{ctx}/elements | Tabs |
| `os.getAssemblyGraph` | /api/assemblies/... | Instance tree |
| `os.getBOM` | /api/assemblies/.../bom | Paged rows |
| `os.export` | /api/partstudios/.../translations | Async job |
| `os.submitRelease` | /api/releasepackages | Approvals |

---

### B3. Async Orchestration
- Start job → progress via SSE → optional webhook → finalize resource  
- Idempotent handlers  
- Queue priorities  
- Backpressure control

References:  
- Webhook Help: https://cad.onshape.com/help/Content/Plans/webhooks.htm

---

### B4. Security
- OAuth2 (users) / API Keys (automation)  
- Secure token store  
- Least privilege scopes  
- Auth mode resource

---

### B5. Resource Lifecycle
- Metadata: (documentId, versionId, elementId)  
- Signed URLs for artifacts  
- Paging for large BOMs  
- Always use Version context

---

### B6. Example Job Flow
1. `tools/call os.export`  
2. Server enqueues translation  
3. Sends progress (queued→running→done)  
4. Onshape webhook triggers completion update  
5. MCP emits `complete` with resource URL

---

### B7. Release Awareness
- Warn on outdated revision  
- Mirror native release states  
- Do not duplicate workflows

---

### B8. Observability
- Trace: docId, ctx, elementId, jobId  
- Metrics: latency, completion rate  
- Feature flags: disable writes quickly

---

## C) Feature Mapping Summary

| MCP Feature | Purpose | Onshape Link |
|--------------|----------|---------------|
| Tools | Invoke CAD/PLM ops | REST API |
| Resources | Artifact/Data | Exports, BOM pages |
| Prompts | Guided steps | Selection, Consent |
| Progress | Async status | SSE / Webhooks |
| Transports | Delivery | stdio / HTTP+SSE |

---

## D) Key References

- Onshape API Intro: https://onshape-public.github.io/docs/api-intro/  
- Onshape Versions: https://cad.onshape.com/help/Content/Primer/versions.htm  
- Release Mgmt: https://cad.onshape.com/help/Content/release_management.htm  
- Exporting Files: https://cad.onshape.com/help/Content/exporting-files.htm  
- BOM Feature: https://www.onshape.com/en/features/bill-of-materials  
- MCP Architecture: https://modelcontextprotocol.io/docs/concepts/architecture  
- MCP Transports: https://modelcontextprotocol.io/docs/concepts/transports  
