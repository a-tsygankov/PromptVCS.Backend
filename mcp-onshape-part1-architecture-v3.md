# MCP × Onshape: Part 1 — Architecture Deep Dive (MCP‑first, REST‑backed) — v3

**Positioning:** MCP is the primary orchestration layer (tools/resources/prompts, progress, streaming). **Onshape REST** is the data plane for CAD/PLM. The MCP server wraps Onshape operations and exposes them as first‑class MCP capabilities that LLMs, IDEs, and agents can discover and use.

---

## A) Agent‑Oriented MCP Functionality (LLM / IDE view)

### A1. Capability discovery → Onshape scope
**MCP feature:** `tools/list`, `resources/list`, `prompts/list` expose what the server can do.  
**Onshape mapping:** Documents, Workspaces/Versions, Elements (Part Studios, Assemblies, Drawings), BOM, Release state. Onshape organizes data as Documents → (Workspaces/Versions) → Elements; versions are immutable, workspaces are live. citeturn0search10turn0search15

**Recommended surface (discovery-friendly names):**
- `os.listDocuments`, `os.listWorkspaces`, `os.listVersions`, `os.listElements`  
- `os.getAssemblyGraph`, `os.getBOM`, `os.getReleaseState`  
- `os.export` (STEP/GLTF/PDF), `os.createVersion`, `os.submitRelease`

> Why it matters to agents: the discovery calls let a slow/long‑thinking model plan multi‑step flows (e.g., “freeze a version, then export, then compare BOM”).

---

### A2. Tool calls (actions) with **progress** and **streaming**
**MCP feature:** JSON‑RPC requests + **progress notifications** over the chosen transport (stdio or **Streamable HTTP** with SSE). citeturn0search4  
**Onshape mapping:** Long operations (translations/exports, BOM traversal, graph queries) run as **jobs** and stream incremental status/partials to the client. Webhooks can fan‑in completion signals. citeturn0search1turn0search6

**Agent benefit:** Works well with **slow/experimental models**—the host receives heartbeat/progress messages and doesn’t block on a single huge response.

---

### A3. Resources (read‑only blobs/handles)
**MCP feature:** Servers can expose **resources** (files, URLs, small datasets) for download/inspection.  
**Onshape mapping:** Exported STEP/GLTF/PDF files, paged BOM CSV/JSON, graph snapshots. **Immutable** resources should be associated with an Onshape **Version** (not a Workspace) to ensure downstream reproducibility. citeturn0search15

---

### A4. Prompts (guided UI/LLM interactions)
**MCP feature:** Predefined **prompts** help an agent collect the right parameters and context iteratively (e.g., “pick document → pick version → pick element”).  
**Onshape mapping:** Prompt chains to traverse document hierarchy, verify release state, and ask consent before writes (release submit/BOM change). **Release workflows** are native to Onshape; MCP prompts should reflect current revision/status instead of inventing parallel states. citeturn0search23

---

### A5. Auth clarity for agents
**Recommended policy messages** (exposed as `resources` or `prompts`):  
- App‑store apps must use **OAuth2**; non‑store automation can use **API keys**. Show current auth mode and scopes to the user/agent. citeturn0search8turn0search12

---

### A6. What an agent can do (capability → Onshape op)

| MCP capability | Onshape concept | Typical agent behaviors |
|---|---|---|
| `os.listDocuments` | Search Documents | Disambiguate names; choose scope for all next steps. citeturn0search10 |
| `os.listWorkspaces` / `os.listVersions` | Branch vs immutable snapshot | Prefer **Version** for exports/ERP sync; Workspace for active edits. citeturn0search15 |
| `os.listElements` | Tabs: Part Studios, Assemblies, Drawings | Type‑aware filtering; pick assembly root for graph/BOM. |
| `os.getAssemblyGraph` | Instances, where‑used | Plan “impact analysis” or part roll‑ups. |
| `os.getBOM` | BOM API | Export/compare released vs working; stage ERP sync. citeturn0search3turn0search18 |
| `os.export` | Translation/export | Kick off STEP/GLTF/PDF; stream progress and return artifact link. citeturn0search1 |
| `os.getReleaseState` / `os.submitRelease` | Release workflow & revisions | Check readiness and submit with approvers/notes. citeturn0search23 |

---

### A7. Slow‑model playbook (agent‑side expectations)
- Expect **202‑style** job semantics via progress events, not a single reply.  
- Prefer Version IDs for any artifact creation/consumption. citeturn0search15  
- Use **capability discovery** first; don’t guess names/IDs.  
- Handle **cancellation** messages and **timeouts** gracefully; resume using `jobId`/resource handles.

---

## B) System Integration Architecture (Developer / Server view)

### B1. Topology (MCP‑first)

```
MCP Client (LLM/IDE)
   └── Transport: stdio  ⟂  Streamable HTTP (+SSE)  ← JSON‑RPC 2.0 messages
        └── MCP Server (Onshape tools/resources/prompts)
              ├─ Tool handlers (use‑cases)
              │    └─ Onshape REST adapter (OAuth2/API key)
              │         ├─ Documents / Workspaces / Versions / Elements
              │         ├─ Release & Revisions
              │         └─ BOM & Translations (exports)
              ├─ Job orchestrator + progress bus (SSE)
              ├─ Resource store (artifacts, pages)
              └─ Webhook receiver (event fan‑in → job updates)
```
**Transports:** MCP defines **stdio** and **Streamable HTTP**; use SSE to stream progress/partials. citeturn0search4

---

### B2. Tool design (MCP methods backed by REST)

| Tool (MCP) | REST to Onshape (examples) | Notes |
|---|---|---|
| `os.listDocuments` | Search/GET documents | Return a compact list with IDs/titles/owners. citeturn0search10 |
| `os.listWorkspaces` | GET workspaces | Always present `workspaceId` and label “Main”. citeturn0search20 |
| `os.listVersions` | GET versions | Immutable; prefer for exports. citeturn0search15 |
| `os.listElements` | GET elements | Include type (Part Studio / Assembly / Drawing). |
| `os.getAssemblyGraph` | GET assembly instances | Stream large graphs in chunks if needed. |
| `os.getBOM` | BOM API endpoints | Provide `view=released|working`. citeturn0search3 |
| `os.export` | Translation/export endpoints | Return `jobId`; update via polling + webhooks. citeturn0search1 |
| `os.getReleaseState` | Release status endpoints | Map to Onshape release objects & revisions. citeturn0search23 |
| `os.submitRelease` | POST release package | Validate candidates; include approvers/notes. citeturn0search23 |

---

### B3. Async orchestration for long CAD ops

**Pattern:** Start job → progress via SSE → optional webhook → finalize resource.  
- **Why:** Onshape exports/translations and deep graph traversals can be slow. Webhooks deliver **HTTP POST JSON** notifications; your receiver updates job state. citeturn0search1turn0search6  
- **Idempotency:** Use request hashes per started job and dedupe retries.  
- **Backpressure:** Queue priorities (interactive vs batch), per‑org limits.  
- **Resilience:** At‑least‑once webhook delivery → design idempotent consumers. citeturn0search1

---

### B4. Security & auth

- **OAuth2** for user‑facing apps; **API Keys** for automation. App‑store submissions must use OAuth2. citeturn0search8turn0search12  
- Store refresh tokens securely; rotate keys; expose current auth mode via a readable MCP resource.  
- Enforce **least privilege** scopes; hide write tools dynamically if scope is insufficient.

---

### B5. Resource lifecycle

- Artifacts (STEP/GLTF/PDF) are stored with metadata: `(documentId, versionId, elementId, microversion, createdAt)`.  
- Provide **signed URLs** or MCP resource URIs; keep BOM/graph outputs **paged** for big models.  
- Prefer **Version** scope for any artifact to guarantee determinism across time. citeturn0search15

---

### B6. Server contracts (sketches)

**Example: `tools/call os.export` request**  
```json
{
  "jsonrpc": "2.0",
  "id": "42",
  "method": "tools/call",
  "params": {
    "name": "os.export",
    "arguments": {
      "documentId": "d123",
      "context": { "versionId": "v456" },
      "elementId": "e789",
      "format": "STEP",
      "options": { "precision": "0.01mm" }
    }
  }
}
```
**Progress (SSE over Streamable HTTP):**  
```
event: progress
data: {"id":"42","stage":"translating","percent":37}
```
**Completion:**  
```
event: complete
data: {"id":"42","result":{"resource":"res://exports/2f7c/part.step"}}
```
**Transport note:** MCP standard transports are **stdio** and **Streamable HTTP**; both carry JSON‑RPC 2.0 messages. citeturn0search4turn0search11turn0search19

---

### B7. Release‑aware behaviors

- If `os.getReleaseState` reports a pending newer revision, annotate `os.export` and `os.getBOM` results with warnings.  
- `os.submitRelease` should surface Onshape’s **native workflow** (states, approvers) rather than inventing custom statuses. citeturn0search23

---

### B8. Observability & ops

- **Tracing:** Tag every Onshape call with `documentId`, `ctx`, `elementId`, `jobId`.  
- **SLOs:** Interaction p95 vs batch p95; webhook delivery lag; translation completion times.  
- **Kill switches:** Feature flags to disable writes/exports.  
- **Glassworks:** When debugging, the Glassworks API Explorer helps verify endpoints/requests quickly. citeturn0search5

---

## C) Quick reference tables

### C1. MCP features → Onshape operations

| MCP Feature | Implementation in this design | Onshape linkage |
|---|---|---|
| Tools | `os.*` methods (see B2) | Onshape REST endpoints (Documents/Elements/BOM/Release) citeturn0search10turn0search3turn0search23 |
| Resources | Artifact URIs + paged datasets | Exports (STEP/GLTF/PDF), BOM/graph pages citeturn0search1 |
| Prompts | Multi‑step pickers & consent prompts | Document→Version→Element selection; release checks citeturn0search23 |
| Progress | SSE/stdio notifications | Jobs + webhook fan‑in for completion citeturn0search1 |
| Transports | stdio / Streamable HTTP | MCP standard transports (JSON‑RPC 2.0) citeturn0search4 |

### C2. Slow‑model safeguards

| Concern | Mechanism |
|---|---|
| High latency | Always async for heavy ops; SSE heartbeats |
| Idle disconnects | Keep‑alive pings; resumable `jobId` |
| Token limits | Paged BOM/graph; small resource manifests |
| Duplicate POSTs | Idempotency keys; request hashing |
| Partial failure | Idempotent webhook handlers; retry with backoff |

---

## D) Sources & pointers

- **Onshape REST Intro & structure (Documents/Workspaces/Versions/Elements):** official dev docs & primer. citeturn0search10turn0search15  
- **Auth:** OAuth2 vs API Keys; app‑store rule. citeturn0search8turn0search12  
- **Webhooks:** delivery model and settings. citeturn0search1turn0search6  
- **Release Mgmt:** workflows & revisions. citeturn0search23  
- **BOM:** feature overview and API availability; sample app. citeturn0search3turn0search18  
- **MCP Transports/Architecture:** stdio & Streamable HTTP; JSON‑RPC basis. citeturn0search4turn0search7turn0search11turn0search19
