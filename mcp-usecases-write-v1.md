# Onshape MCP Gateway — Write-Enabled Use Cases (Regenerated)

This document defines 10 write-capable scenarios for the MCP gateway. Each use case includes goal, model requirements, declared MCP interfaces, inline prompt template (YAML), example prompts, JSON‑RPC request, difficulty, and cross‑references.

Safety requirements: All write tools must support `dryRun`, `idempotencyKey` where applicable, and audit logging. Destructive actions require a separate `confirmToken` obtained from a preview step.

---

## Table of Contents
1. Create Document from Template
2. Duplicate Workspace
3. Create or Update Custom Properties
4. Create Assembly Configuration
5. Batch Update Metadata
6. Workflow State Change
7. Create Release Package (bundle and attach)
8. Remove Orphaned Revisions (with confirmation)
9. Generate and Attach Drawing
10. Apply Transformation (scripted change)

---

### 1. Create Document from Template

Goal. Create a new document using a predefined template and seed metadata.

Model requirements. None; optional small model for naming suggestions.

MCP interfaces (declared).
- Tool: `onshape.document.create(name, templateId?, metadata?, dryRun?, idempotencyKey?)`

Inline prompt (YAML).
```yaml
name: document.create.template
description: Create a new document from a template with initial metadata.
template: |
  Name: {name}
  Template: {template}
  Metadata: {metadata}
  Confirm creation only if dry-run result matches intent.
```

Prompt examples.
- Create new document Gearbox v3 from MechanicalTemplate with owner ME team.

JSON‑RPC request.
```json
{"jsonrpc":"2.0","id":"w1","method":"tools/call","params":{
  "name":"onshape.document.create",
  "arguments":{"name":"Gearbox v3","templateId":"tpl-mech","metadata":{"owner":"ME"},"dryRun":true,"idempotencyKey":"doc-gearbox-v3"}
}}
```

Difficulty. Medium.

References. Uses `onshape.document.create`.

---

### 2. Duplicate Workspace

Goal. Duplicate a workspace for branching work.

Model requirements. None.

MCP interfaces (declared).
- Tool: `onshape.workspace.duplicate(documentId, workspaceId, newName, dryRun?, idempotencyKey?)`

Inline prompt (YAML).
```yaml
name: workspace.duplicate
description: Create a duplicate workspace for parallel development.
template: |
  Document: {documentId}
  Source workspace: {workspaceId}
  New name: {newName}
  Perform dry-run first; proceed only with explicit confirmation.
```

Prompt examples.
- Duplicate workspace w123 of Gearbox to Gearbox v3-dev.

JSON‑RPC request.
```json
{"jsonrpc":"2.0","id":"w2","method":"tools/call","params":{
  "name":"onshape.workspace.duplicate",
  "arguments":{"documentId":"d123","workspaceId":"w123","newName":"Gearbox v3-dev","dryRun":true,"idempotencyKey":"dup-w123-v3dev"}
}}
```

Difficulty. Medium.

References. Uses `onshape.workspace.duplicate`.

---

### 3. Create or Update Custom Properties

Goal. Add or update custom properties on parts/documents.

Model requirements. Optional small model to convert natural language to property JSON.

MCP interfaces (declared).
- Tool: `onshape.properties.upsert(targetIds[], properties{}, dryRun?, idempotencyKey?)`

Inline prompt (YAML).
```yaml
name: properties.upsert
description: Safely upsert custom properties across multiple targets.
template: |
  Targets: {targets}
  Properties: {properties}
  Explain the proposed diff; apply only if confirmed.
```

Prompt examples.
- Set Material=A2-70 and Tag=CorrosionResistant for all fasteners.

JSON‑RPC request.
```json
{"jsonrpc":"2.0","id":"w3","method":"tools/call","params":{
  "name":"onshape.properties.upsert",
  "arguments":{"targetIds":["p1","p2"],"properties":{"Material":"A2-70","Tag":"CorrosionResistant"},"dryRun":true,"idempotencyKey":"props-fasteners-a2"}
}}
```

Difficulty. Medium.

References. Uses `onshape.properties.upsert`.

---

### 4. Create Assembly Configuration

Goal. Define or update configuration parameters for an assembly.

Model requirements. Optional small model for parameter description parsing.

MCP interfaces (declared).
- Tool: `onshape.assembly.config.upsert(documentId, workspaceId, elementId, params[], dryRun?, idempotencyKey?)`

Inline prompt (YAML).
```yaml
name: assembly.config.author
description: Author or update assembly configuration parameters.
template: |
  Parameters: {params}
  Validate consistency and units; preview changes before apply.
```

Prompt examples.
- Create configuration with gearRatio=3.2 and housingThickness=4mm.

JSON‑RPC request.
```json
{"jsonrpc":"2.0","id":"w4","method":"tools/call","params":{
  "name":"onshape.assembly.config.upsert",
  "arguments":{"documentId":"d123","workspaceId":"w456","elementId":"e789","params":[{"key":"gearRatio","value":"3.2"},{"key":"housingThickness","value":"4mm"}],"dryRun":true,"idempotencyKey":"cfg-gearbox-v3"}
}}
```

Difficulty. Hard.

References. Uses `onshape.assembly.config.upsert`.

---

### 5. Batch Update Metadata

Goal. Safely apply metadata patches to multiple parts.

Model requirements. Optional small model for NL to filter JSON.

MCP interfaces (declared).
- Tool: `onshape.metadata.patch(partIds[], patch{}, dryRun?, idempotencyKey?)`

Inline prompt (YAML).
```yaml
name: metadata.bulkedit
description: Review and apply a metadata patch across selected parts.
template: |
  Patch: {patch}
  Part IDs: {partIds}
  Show a diff and confirm before applying.
```

Prompt examples.
- Update Finish=HardAnodized for all aluminum brackets (dry run first).

JSON‑RPC request.
```json
{"jsonrpc":"2.0","id":"w5","method":"tools/call","params":{
  "name":"onshape.metadata.patch",
  "arguments":{"partIds":["p10","p22"],"patch":{"Finish":"HardAnodized"},"dryRun":true,"idempotencyKey":"patch-brackets-HA"}
}}
```

Difficulty. Medium.

References. Uses `onshape.metadata.patch`.

---

### 6. Workflow State Change

Goal. Transition documents between workflow states with policy checks.

Model requirements. Optional model to craft audit comments; policy enforced in gateway.

MCP interfaces (declared).
- Tool: `onshape.release.transition(documentId, targetState, comment, dryRun?, idempotencyKey?)`
- Resource: `onshape.release.readiness(documentId)`

Inline prompt (YAML).
```yaml
name: release.check-and-transition
description: Check readiness and, if satisfied, transition workflow state.
template: |
  Readiness: {checks}
  Target state: {target}
  Justification: {comment}
  Perform dry-run and require explicit confirmation.
```

Prompt examples.
- If Gearbox v2 passes readiness, move to Release Candidate with comment "QA complete".

JSON‑RPC request.
```json
{"jsonrpc":"2.0","id":"w6","method":"tools/call","params":{
  "name":"onshape.release.transition",
  "arguments":{"documentId":"d123","targetState":"ReleaseCandidate","comment":"QA complete","dryRun":true,"idempotencyKey":"rel-gbx-v2-rc"}
}}
```

Difficulty. Medium.

References. Uses `onshape.release.transition`, `onshape.release.readiness`.

---

### 7. Create Release Package (bundle and attach)

Goal. Export required artifacts and bundle into a zip with manifest, then attach to PLM.

Model requirements. None; optional model for manifest text.

MCP interfaces (declared).
- Tool: `onshape.export.start(documentId, workspaceId, elementId, format)`
- Tool: `onshape.export.poll(jobId)`
- Tool: `gateway.bundle.zip(files[])`
- Tool: `plm.change.attachExport(changeId, fileUrl)`

Inline prompt (YAML).
```yaml
name: release.package.create
description: Create a release package and attach to the PLM change.
template: |
  Artifacts: {artifacts}
  Bundle into a single ZIP with a manifest.
  Attach to PLM change {changeId}.
```

Prompt examples.
- Create release package for Gearbox v3 with STEP, PDF drawings, and BOM CSV.

JSON‑RPC (example: bundle).
```json
{"jsonrpc":"2.0","id":"w7","method":"tools/call","params":{
  "name":"gateway.bundle.zip",
  "arguments":{"files":[
    {"name":"gearbox.step","url":"https://minio/presigned1"},
    {"name":"gearbox.pdf","url":"https://minio/presigned2"}
  ]}
}}
```

Difficulty. Hard.

References. Uses `onshape.export.start`, `onshape.export.poll`, `gateway.bundle.zip`, `plm.change.attachExport`.

---

### 8. Remove Orphaned Revisions (with confirmation)

Goal. Delete orphaned or superseded revisions after review.

Model requirements. None; gateway requires confirmation and dry-run.

MCP interfaces (declared).
- Tool: `onshape.revision.delete(revisionIds[], confirmToken, dryRun?, idempotencyKey?)`

Inline prompt (YAML).
```yaml
name: revision.cleanup
description: Preview and confirm deletion of orphaned revisions.
template: |
  Candidates: {revisionIds}
  Require a confirm token and show a dry-run summary before delete.
```

Prompt examples.
- List candidates for deletion and proceed only with explicit confirm token.

JSON‑RPC request.
```json
{"jsonrpc":"2.0","id":"w8","method":"tools/call","params":{
  "name":"onshape.revision.delete",
  "arguments":{"revisionIds":["r1","r2"],"confirmToken":"CONFIRM-123","dryRun":true,"idempotencyKey":"rev-clean-2025-09"}
}}
```

Difficulty. Hard.

References. Uses `onshape.revision.delete`.

---

### 9. Generate and Attach Drawing

Goal. Generate a drawing for a part/assembly using a template and attach to the document.

Model requirements. Optional model to compose drawing notes.

MCP interfaces (declared).
- Tool: `onshape.drawing.generate(documentId, workspaceId, elementId, templateId, dryRun?, idempotencyKey?)`
- Tool: `onshape.document.attach(elementId, attachmentUrl)`

Inline prompt (YAML).
```yaml
name: drawing.generate
description: Generate a drawing using a template and attach to the document.
template: |
  Template ID: {templateId}
  Element: {elementId}
  Notes: {notes}
  Produce a dry-run first with page size and scale.
```

Prompt examples.
- Create drawing for motor bracket using A3 template and attach to document.

JSON‑RPC request.
```json
{"jsonrpc":"2.0","id":"w9","method":"tools/call","params":{
  "name":"onshape.drawing.generate",
  "arguments":{"documentId":"d123","workspaceId":"w456","elementId":"e789","templateId":"tpl-A3","dryRun":true,"idempotencyKey":"draw-motor-A3"}
}}
```

Difficulty. Medium.

References. Uses `onshape.drawing.generate`, `onshape.document.attach`.

---

### 10. Apply Transformation (scripted change)

Goal. Apply a deterministic transformation (e.g., rename parts, fix layer names, normalize units).

Model requirements. None.

MCP interfaces (declared).
- Tool: `onshape.transform.apply(documentId, workspaceId, plan[], idempotencyKey?, dryRun?)`

Inline prompt (YAML).
```yaml
name: transform.plan.review
description: Review a deterministic transformation plan before applying.
template: |
  Plan: {plan}
  Output a summary of intended changes and conflicts; require confirmation.
```

Prompt examples.
- Rename all parts with prefix GBX_ and normalize units to mm.

JSON‑RPC request.
```json
{"jsonrpc":"2.0","id":"w10","method":"tools/call","params":{
  "name":"onshape.transform.apply",
  "arguments":{"documentId":"d123","workspaceId":"w456","plan":[{"op":"rename","pattern":"*","prefix":"GBX_"},{"op":"units","value":"mm"}],"dryRun":true,"idempotencyKey":"tx-gbx-mm"}
}}
```

Difficulty. Medium.

References. Uses `onshape.transform.apply`.
