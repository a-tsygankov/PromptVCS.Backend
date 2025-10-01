# Onshape MCP Gateway — Architecture (V3.1)

This version supersedes the previous architecture guide and expands Sections A and B with deeper Onshape‑specific detail, long‑running job handling, security, and implementation examples for Java and .NET.

## Versioning
- Tag: V3.1
- Scope: Architecture sections A and B expanded; examples are runnable locally and map 1:1 to AWS.
- Compatibility: MCP surface remains stable with prior versions (resources/tools/prompts).

---

## A) System Architecture

### A1. Topology (Local‑First, Prod‑Ready)
```
[MCP Client] --HTTP(JSON-RPC)--> mcp-gateway (Java OR .NET)
                                  |-- Onshape API (local via Rancher; prod: cad.onshape.com)
                                  |-- MinIO/S3 (exports, artifacts)
                                  |-- Redis (jobs, rate limits, idempotency)
                                  |-- Auth (Keycloak in dev; Cognito/OIDC in prod)
                                  |-- Optional: Ollama or cloud model provider
```

### A2. Long‑Running Jobs in Onshape: Progress, Polling, and Streaming

Problem. Exports/translations and some heavy analyses run asynchronously in Onshape. Your gateway must expose these as MCP tools without blocking.

Patterns.
1. Fire‑and‑Poll (baseline).
   - tools/call → onshape.export.start(...) returns {jobId}.
   - Gateway queues a worker task (exportWorker) that polls Onshape’s job endpoint at an exponential backoff (e.g., 1s→2s→4s, cap 15s).
   - When Onshape completes, gateway uploads result to MinIO/S3, records {status,url,checksum,completedAt} in Redis job:{id}.

2. Server‑Sent Events (SSE) from gateway to client (streamed progress).
   - MCP clients use HTTP; your gateway can offer /mcp/stream?jobId=... that sends SSE lines like: data: {"progress":55,"stage":"meshing"}.
   - The MCP tool can include a streamToken in the initial result, enabling the client to optionally subscribe.

3. Chunked Progress via MCP polling (no SSE).
   - onshape.export.poll(jobId) returns {status, progress, stage, url?}.
   - For live UIs, call poll every 2–4 seconds with jitter.

Implementation notes.
- Use a job state machine: queued → running → uploading → complete | failed.
- Persist progress snapshots in Redis under job:{id}:progress to support SSE or polling.
- For backpressure, cap concurrent external polls per job and share results between worker loops.

Example timeline (export STEP).
1) Client: tools/call onshape.export.start → {"jobId":"job-123","streamToken":"st-abc"}
2) Worker: polls Onshape → updates {progress,stage} in Redis.
3) Client: either subscribes to /mcp/stream?token=st-abc or calls onshape.export.poll(jobId).
4) Worker: on completion uploads to MinIO → writes {status:"complete", url:"...", checksum:"..."}.
5) Client: final poll returns signed URL for download.

Retries.
- Retry transient Onshape HTTP 5xx with exponential backoff and jitter; stop after N attempts or 10 minutes wall time.
- On failure, include lastStage, attempts, errorSummary in job record.

### A3. Transport and JSON‑RPC Contracts (Expanded)

Endpoint. POST /mcp
Methods.
- resources/read — pure reads, under 2s typical.
- tools/call — actions, may return immediately with jobId.
- prompts/list and prompts/get — curated templates (few‑shot).

Request/Response Shapes.
- tools/call (sync example):
{
  "jsonrpc":"2.0","id":"42","method":"tools/call","params":{
    "name":"onshape.documents.search",
    "arguments":{"query":"gearbox","owners":["me-team"]}
  }}
Result (sync):
{"jsonrpc":"2.0","id":"42","result":{"rows":[{"id":"d1","name":"Gearbox V2","owner":"ME"}]}}

- tools/call (async job example):
{"jsonrpc":"2.0","id":"43","method":"tools/call","params":{
  "name":"onshape.export.start",
  "arguments":{"documentId":"d123","workspaceId":"w456","elementId":"e789","format":"STEP"}
}}
Result (async):
{"jsonrpc":"2.0","id":"43","result":{"status":"queued","jobId":"job-123","streamToken":"st-abc"}}

- resources/read example:
{"jsonrpc":"2.0","id":"44","method":"resources/read","params":{
  "name":"onshape.bom.get","arguments":{"documentId":"d123","workspaceId":"w1","elementId":"e2"}
}}

Error mapping.
- JSON‑RPC error.code values: -32601 (method not found), -32000 (policy denied), -32001 (validation), -32002 (upstream Onshape error), -32003 (timeout).

### A4. Idempotency, Rate Limits, and Concurrency (Expanded)

Idempotency.
- For mutating tools (write file), require idempotencyKey. Store the hash of normalized arguments with a TTL (e.g., 24h). If key repeats, return the previous result.
- For long jobs, key includes {documentId, elementId, format} to avoid duplicate exports.

Rate limits.
- Token bucket per {userId}:{tool}; soft limits for read, stricter for write/exports (e.g., 10 RPS read, 2 RPS write).

Concurrency.
- Per‑job lock (Redis SETNX) to prevent multiple workers processing same job.
- Cap concurrent exports to protect Onshape and your own bandwidth (configurable per environment).

### A5. Storage and Artifact Handling
- Use MinIO locally with path‑style URLs; presign on GET for 15–60 minutes.
- Store checksum and size; verify before returning to clients.

### A6. Observability (Expanded with Examples)

Metrics (examples).
- mcp_tool_calls_total{tool="onshape.export.start",result="queued"}
- mcp_job_duration_seconds{tool="onshape.export",status="complete"}
- onshape_http_requests_total{endpoint="/exports",status="200"}
- policy_denied_total{tool="onshape.release.transition"}

Logs (structured).
{"ts":"2025-10-01T13:15:00Z","user":"u-17","tool":"onshape.export.start","argsHash":"b1f...","jobId":"job-123","stage":"queued"}

Traces.
- Span 1: mcp.tools.call (parent) → span 2: onshape.http.export → span 3: minio.putobject.

Dashboards.
- Export funnel: queued → running → uploading → complete/failed with per‑stage latency percentiles.
- Error heatmap by Onshape endpoint.

---

## B) Implementation Details (Onshape‑Focused)

### B1. Onshape API Binding
- Create a thin client with typed methods: startExport, getExportStatus, getBOM, getChangeLog, getFeatureScript, etc.
- Normalize Onshape JSON to gateway DTOs; include documentId, workspaceId, versionId, elementId explicitly in every DTO.

### B2. Authentication and Security (Gateway → Onshape)
- API Key + Secret (HMAC). Use request signing; keep secrets in env only for dev, in Secrets Manager for prod.
- OAuth2 (user‑delegated). Store encrypted refresh tokens; exchange for short‑lived access tokens per request.
- Scopes. Gate tool execution by policy (onshape:read.*, onshape:write.*, onshape:export).
- Least privilege. Prefer OAuth2 for multi‑user tools; reserve API keys for headless service accounts.

### B3. Request Signing (HMAC) Basics
- Build canonical string from method, path, date, and content hash (implementation detail depends on your Onshape deployment).
- Add Authorization header Onshape-HMAC <keyId>:<signature>.

### B4. OAuth2 Flow (Dev and Prod)
- Dev: Keycloak as IdP, client‑credentials for the MCP client; authorization‑code for user‑delegated flows.
- Prod: Cognito/Okta/Onshape’s OAuth endpoint; store refresh tokens encrypted; rotate signing keys.

### B5. Java 21 Examples (Expanded)

Export Worker (polling + upload).
```java
@Component
public class ExportWorker implements Runnable {
  private final JobRepo repo; private final OnshapeClient onshape; private final S3Storage s3;
  @Scheduled(fixedDelay = 1000L) public void run() {
    repo.findRunningExports().forEach(job -> {
      var st = onshape.getExportStatus(job.onshapeJobId());
      repo.updateProgress(job.id(), st.progress(), st.stage());
      if (st.isComplete()) {
        var bytes = onshape.downloadExport(st);
        var url = s3.putAndPresign(job.outputKey(), bytes, "model/step");
        repo.complete(job.id(), url, st.checksum());
      } else if (st.isFailed()) {
        repo.fail(job.id(), st.error());
      }
    });
  }
}
```

SSE endpoint (progress streaming).
```java
@GetMapping(path="/mcp/stream", produces=MediaType.TEXT_EVENT_STREAM_VALUE)
public Flux<ServerSentEvent<String>> stream(@RequestParam String token) {
  return jobEvents.byToken(token).map(ev -> ServerSentEvent.builder(ev.json()).build());
}
```

### B6. .NET 8/9 Examples (Expanded)

Export Worker (Hosted Service).
```csharp
public sealed class ExportWorker(IJobRepo repo, OnshapeClient onshape, IS3Storage s3, ILogger<ExportWorker> log) : BackgroundService
{
  protected override async Task ExecuteAsync(CancellationToken ct)
  {
    while (!ct.IsCancellationRequested)
    {
      await foreach (var job in repo.FindRunningExportsAsync(ct))
      {
        var st = await onshape.GetExportStatusAsync(job.OnshapeJobId, ct);
        await repo.UpdateProgressAsync(job.Id, st.Progress, st.Stage, ct);
        if (st.IsComplete)
        {
          var bytes = await onshape.DownloadExportAsync(st, ct);
          var url = await s3.PutAndPresignAsync(job.OutputKey, bytes, "model/step", ct);
          await repo.CompleteAsync(job.Id, url, st.Checksum, ct);
        }
        else if (st.IsFailed)
        {
          await repo.FailAsync(job.Id, st.Error, ct);
        }
      }
      await Task.Delay(TimeSpan.FromSeconds(1), ct);
    }
  }
}
```

Minimal SSE endpoint (progress).
```csharp
app.MapGet("/mcp/stream", async (HttpContext ctx, IJobEvents events) =>
{
    ctx.Response.Headers.CacheControl = "no-cache";
    ctx.Response.ContentType = "text/event-stream";
    var token = ctx.Request.Query["token"].ToString();
    await foreach (var json in events.ByTokenAsync(token, ctx.RequestAborted))
    {
        await ctx.Response.WriteAsync($"data: {json}\n\n");
        await ctx.Response.Body.FlushAsync();
    }
});
```

### B7. Examples: Policy, Idempotency, and Validation

Java policy guard (per tool).
```java
public void assertAllowed(String userId, String tool, Map<String,Object> args) {
  if (!policy.isAllowed(userId, tool)) throw new McpError(-32000, "Policy denied");
  if (tool.startsWith("onshape.") && tool.contains("transition") && Boolean.TRUE.equals(args.get("dryRun"))) return;
}
```

.NET idempotency handler.
```csharp
public async Task<TResult> WithIdempotencyAsync<TResult>(string key, Func<Task<TResult>> work, TimeSpan ttl)
{
  if (await store.TryGetAsync<TResult>(key) is { } cached) return cached;
  var result = await work();
  await store.PutAsync(key, result, ttl);
  return result;
}
```

Validation example (metadata patch).
- Reject empty partIds.
- Limit patch keys to an approved whitelist.
- Enforce dryRun=true when partIds.Count > 1000 in dev.

---

Appendix: Configuration Defaults
- Poll interval: 2s (max backoff 15s)
- Export concurrency: 4 local / 16 prod per task
- Signed URL TTL: 30 minutes
- Job TTL: 7 days
