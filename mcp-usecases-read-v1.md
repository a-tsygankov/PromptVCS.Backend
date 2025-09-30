# Onshape MCP Gateway — Read-Only Use Cases (Regenerated)

This document defines 10 read-only scenarios for the MCP gateway. Each use case includes goal, model requirements, declared MCP interfaces (resources/tools), inline prompt template (YAML), example prompts, JSON‑RPC request, difficulty, and cross‑references.

Scope: Read-only means no mutation of Onshape data is performed. Long‑running operations that only read (e.g., async export) are allowed, but any state changes are disabled in this file.

---

## Table of Contents
1. Search and Summarize Documents
2. BOM Explosion and Risk Summary (Read)
3. Async Export (Read, download only)
4. Mate and Constraint Diagnostics (Read)
5. Drawing QA Checklist (Read)
6. Release Readiness Report (Read)
7. Change Log Summarization
8. FeatureScript Explainer
9. Metadata Bulk Read
10. PLM Sync Readbacks

---

### 1. Search and Summarize Documents

Goal. Locate relevant documents and summarize recent activity.

Model requirements. Optional small reasoning model (3–8B).

MCP interfaces (declared).
- Tool: `onshape.documents.search(query, owners?, tags?, dateRange?)`
- Resource: `onshape.documents.recent(limit?)`

Inline prompt (YAML).
```yaml
name: search.summarize
description: Summarize search results and highlight the most relevant documents.
template: |
  You are assisting with Onshape document triage.
  Query: "{query}"
  Rows: {rows}
  Output: the top 3 documents by likely relevance with a one-sentence rationale.
```

Prompt examples.
- Find the latest gearbox document owned by ME team and summarize the last three changes.
- List documents changed in the last week mentioning bearing.

JSON‑RPC request.
```json
{"jsonrpc":"2.0","id":"s1","method":"tools/call","params":{
  "name":"onshape.documents.search",
  "arguments":{"query":"gearbox","owners":["me-team"],"dateRange":"last7d"}
}}
```

Difficulty. Easy.

References. Uses `onshape.documents.search`, `onshape.documents.recent`.

---

### 2. BOM Explosion and Risk Summary (Read)

Goal. Retrieve a BOM and present a prioritized risk summary without mutating anything.

Model requirements. Reasoning 7–8B or rules-only gateway.

MCP interfaces (declared).
- Resource: `onshape.bom.get(documentId, workspaceId, elementId)`

Inline prompt (YAML).
```yaml
name: bom.risk.summarize
description: Identify and prioritize BOM risks using read-only attributes.
template: |
  BOM rows: {bom}
  Risk rules (read-only): lifecycle != "Active", leadTimeDays > {lead_threshold}, vendor == null.
  Produce a JSON array: [{partId, risks: ["obsolete","long_lead","no_vendor"], note}].
```

Prompt examples.
- Show BOM for motor assembly and flag obsolete or long-lead items.
- Summarize top 5 BOM risks by lead time and missing metadata.

JSON‑RPC request.
```json
{"jsonrpc":"2.0","id":"bom1","method":"resources/read","params":{
  "name":"onshape.bom.get",
  "arguments":{"documentId":"d123","workspaceId":"w456","elementId":"e789"}
}}
```

Difficulty. Medium.

References. Uses `onshape.bom.get`.

---

### 3. Async Export (Read, download only)

Goal. Start a server-side export job and provide a pre-signed download link. No mutation of design data.

Model requirements. None.

MCP interfaces (declared).
- Tool: `onshape.export.start(documentId, workspaceId, elementId, format)`
- Tool: `onshape.export.poll(jobId)`

Inline prompt (YAML).
```yaml
name: export.notify
description: Notify user about the status of a read-only export.
template: |
  Export job status: {status}
  If complete, provide the pre-signed URL and checksum.
```

Prompt examples.
- Export the gearbox housing to STEP and notify me when ready.

JSON‑RPC requests.
```json
{"jsonrpc":"2.0","id":"ex1","method":"tools/call","params":{
  "name":"onshape.export.start",
  "arguments":{"documentId":"d123","workspaceId":"w456","elementId":"e789","format":"STEP"}
}}
```
```json
{"jsonrpc":"2.0","id":"ex2","method":"tools/call","params":{
  "name":"onshape.export.poll","arguments":{"jobId":"job-9d1"}
}}
```

Difficulty. Easy.

References. Uses `onshape.export.start`, `onshape.export.poll`.

---

### 4. Mate and Constraint Diagnostics (Read)

Goal. Inspect assemblies for constraint issues and propose fixes (advice only).

Model requirements. Small reasoning model (7–8B).

MCP interfaces (declared).
- Tool: `onshape.assembly.inspect(documentId, workspaceId, elementId)`

Inline prompt (YAML).
```yaml
name: assembly.mates.diagnose
description: Propose minimal adjustments to resolve assembly constraint issues in read-only mode.
template: |
  Diagnostics: {diagnostics}
  List problems and propose the minimal set of changes a human could make.
```

Prompt examples.
- List over-constrained subassemblies and which mates to adjust.
- Explain why wheel does not rotate and propose minimal fix.

JSON‑RPC request.
```json
{"jsonrpc":"2.0","id":"a1","method":"tools/call","params":{
  "name":"onshape.assembly.inspect",
  "arguments":{"documentId":"d123","workspaceId":"w456","elementId":"e789"}
}}
```

Difficulty. Medium.

References. Uses `onshape.assembly.inspect`.

---

### 5. Drawing QA Checklist (Read)

Goal. Validate drawings against house rules, produce checklist only.

Model requirements. Optional small model for formatting output.

MCP interfaces (declared).
- Tool: `onshape.drawing.validate(documentId, elementId)`

Inline prompt (YAML).
```yaml
name: qa.drawing.checklist
description: Produce a concise checklist from read-only drawing validation findings.
template: |
  Findings: {findings}
  Output a short, grouped checklist by severity with direct actions (no writes).
```

Prompt examples.
- Check drawing gearbox housing and produce a fix checklist.

JSON‑RPC request.
```json
{"jsonrpc":"2.0","id":"dq1","method":"tools/call","params":{
  "name":"onshape.drawing.validate",
  "arguments":{"documentId":"d123","elementId":"e321"}
}}
```

Difficulty. Medium.

References. Uses `onshape.drawing.validate`.

---

### 6. Release Readiness Report (Read)

Goal. Verify release gating and report blockers (no transition).

Model requirements. Optional small reasoning.

MCP interfaces (declared).
- Resource: `onshape.release.readiness(documentId)`

Inline prompt (YAML).
```yaml
name: release.readiness.report
description: Summarize readiness checks and blockers without changing states.
template: |
  Checks: {checks}
  Output: pass/fail per check, with blocking reasons and owners.
```

Prompt examples.
- Verify if Gearbox v2 is ready for Release Candidate and list missing items.

JSON‑RPC request.
```json
{"jsonrpc":"2.0","id":"rel1","method":"resources/read","params":{
  "name":"onshape.release.readiness","arguments":{"documentId":"d123"}
}}
```

Difficulty. Medium.

References. Uses `onshape.release.readiness`.

---

### 7. Change Log Summarization

Goal. Summarize geometry-affecting changes since a date.

Model requirements. Tiny summarizer.

MCP interfaces (declared).
- Resource: `onshape.changelog.list(documentId, since)`

Inline prompt (YAML).
```yaml
name: changelog.summarize
description: Condense change log entries and highlight impactful changes.
template: |
  Entries: {entries}
  Produce the 5 most impactful changes and recommended follow-ups.
```

Prompt examples.
- Summarize all geometry-affecting changes since 2025-09-01.

JSON‑RPC request.
```json
{"jsonrpc":"2.0","id":"cl1","method":"resources/read","params":{
  "name":"onshape.changelog.list","arguments":{"documentId":"d123","since":"2025-09-01"}
}}
```

Difficulty. Easy.

References. Uses `onshape.changelog.list`.

---

### 8. FeatureScript Explainer

Goal. Explain FeatureScript logic and pitfalls.

Model requirements. 7–8B preferred for code explanation.

MCP interfaces (declared).
- Resource: `onshape.featurescript.source(elementId)`

Inline prompt (YAML).
```yaml
name: featurescript.explain
description: Explain behavior, inputs/outputs, and performance risks of a FeatureScript snippet.
template: |
  Code excerpt:
  ```
  {code}
  ```
  Summarize purpose, parameters, return values, and performance/pitfalls.
```

Prompt examples.
- Explain what this FeatureScript does and give a minimal usage example.

JSON‑RPC request.
```json
{"jsonrpc":"2.0","id":"fs1","method":"resources/read","params":{
  "name":"onshape.featurescript.source","arguments":{"elementId":"e777"}
}}
```

Difficulty. Medium.

References. Uses `onshape.featurescript.source`.

---

### 9. Metadata Bulk Read

Goal. Read metadata across many parts for review.

Model requirements. None.

MCP interfaces (declared).
- Resource: `onshape.metadata.list(documentId, workspaceId, filter?)`

Inline prompt (YAML).
```yaml
name: metadata.review
description: Provide an analysis of retrieved metadata without writing.
template: |
  Metadata rows: {rows}
  Group by key attributes and flag inconsistencies for human review.
```

Prompt examples.
- List materials for all fasteners and group by vendor.

JSON‑RPC request.
```json
{"jsonrpc":"2.0","id":"mdr1","method":"resources/read","params":{
  "name":"onshape.metadata.list",
  "arguments":{"documentId":"d123","workspaceId":"w456","filter":{"category":"fasteners"}}
}}
```

Difficulty. Easy.

References. Uses `onshape.metadata.list`.

---

### 10. PLM Sync Readbacks

Goal. Prepare PLM change payloads and list attachments without writing.

Model requirements. Optional small model for formatting.

MCP interfaces (declared).
- Resource: `plm.change.preview(plmSystem, documentId, since?)`

Inline prompt (YAML).
```yaml
name: plm.sync.readonly
description: Prepare a PLM change preview with attachment list; no write operations.
template: |
  PLM system: {plm_system}
  Inputs: {inputs}
  Output: change description, affected items, and artifact list.
```

Prompt examples.
- Prepare PLM change preview for Gearbox Rev C and list artifacts to attach.

JSON‑RPC request.
```json
{"jsonrpc":"2.0","id":"plm1","method":"resources/read","params":{
  "name":"plm.change.preview",
  "arguments":{"plmSystem":"Windchill","documentId":"d123","since":"2025-08-01"}
}}
```

Difficulty. Medium.

References. Uses `plm.change.preview`.
