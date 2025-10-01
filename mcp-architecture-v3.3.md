# Onshape MCP Gateway — Architecture (V3.3 Living Spec)

This living specification merges **V3.1** and **V3.2**, incorporating Onshape-specific patterns, streaming enhancements, multi-tenant controls, and refined Java/.NET examples.

---

## Changelog

| Version | Date       | Summary                                                                 |
|----------|------------|--------------------------------------------------------------------------|
| V3.1     | 2025-10-01 | Expanded A2–A6, B5–B7 with examples for long-running jobs, JSON-RPC, idempotency, observability. |
| V3.2     | 2025-10-02 | Added streaming heartbeats, multipart uploads, circuit breakers, tenancy & mTLS security. |
| V3.3     | 2025-10-03 | Unified specification with anchors, refined layout, consistent formatting, appendix. |

---

# A) System Architecture

## A1. Topology (Local-First, Prod-Ready)

```
[MCP Client] --HTTP(JSON-RPC)--> mcp-gateway (Java OR .NET)
                                  |-- Onshape API (local via Rancher; prod: cad.onshape.com)
                                  |-- MinIO/S3 (exports, artifacts)
                                  |-- Redis (jobs, rate limits, idempotency)
                                  |-- Auth (Keycloak in dev; Cognito/OIDC in prod)
                                  |-- Optional: Ollama or cloud model provider
```

Local instances can run fully offline (Onshape stub + MinIO) for development.  
Production uses real Onshape endpoints and cloud S3 storage.

---

<a name="A2"></a>
## A2. Long-Running Jobs in Onshape: Progress, Polling, and Streaming

### Overview
Many Onshape operations (e.g., exports, translations, complex analyses) execute asynchronously.  
MCP Gateway exposes these operations as **tools** returning `jobId` and **optionally** `streamToken` for live progress updates.

### Patterns

#### 1. Fire-and-Poll (Baseline)
- `tools/call → onshape.export.start(...)` returns `{jobId}`
- Worker polls `/exports/{id}/status` at exponential backoff (1s → 2s → 4s; max 15s)
- On completion: uploads artifact → records `{status,url,checksum}` in Redis

#### 2. Server-Sent Events (SSE)
- Gateway exposes `/mcp/stream?token={streamToken}`
- Emits JSON events like:
```
data: {"progress":55,"stage":"meshing"}
```
- Useful for dashboards or terminal progress

#### 3. Chunked Polling
- Client polls `onshape.export.poll(jobId)` every few seconds
- Gateway merges Onshape and worker state; returns aggregated `{progress, stage, url}`

### Implementation Notes
- State machine: `queued → running → uploading → complete|failed`
- Redis persistence: `job:{id}:progress` + `job:{id}:meta`
- Backpressure: share poll results between workers

### Addenda (V3.2)
- **Heartbeat events**: `{t, stage, pct}` every 10s even if % not updated  
- **Partial artifacts**: multipart upload exposes `partsCompleted`  
- **Client backoff hints**: `suggestedNextPollMs` for adaptive polling

---

<a name="A3"></a>
## A3. Transport and JSON-RPC Contracts

### Endpoint
`POST /mcp`

### Methods
- `resources/read` — read-only  
- `tools/call` — actions (sync or async)  
- `prompts/list`, `prompts/get` — templates

### Examples

**Synchronous tool**
```json
{"jsonrpc":"2.0","id":"42","method":"tools/call","params":{
  "name":"onshape.documents.search",
  "arguments":{"query":"gearbox","owners":["me-team"]}
}}
```
**Result**
```json
{"jsonrpc":"2.0","id":"42","result":{"rows":[{"id":"d1","name":"Gearbox V2"}]}}
```

**Asynchronous job**
```json
{"jsonrpc":"2.0","id":"43","method":"tools/call","params":{
  "name":"onshape.export.start",
  "arguments":{"documentId":"d123","workspaceId":"w456","elementId":"e789","format":"STEP"}
}}
```
**Result**
```json
{"jsonrpc":"2.0","id":"43","result":{"status":"queued","jobId":"job-123","streamToken":"st-abc"}}
```

**Error Codes**
| Code | Meaning |
|------|----------|
| -32601 | Method not found |
| -32000 | Policy denied |
| -32001 | Validation error |
| -32002 | Upstream Onshape error |
| -32003 | Timeout |

### Addenda (V3.2)
- Optional WebSocket `/ws` mirror for dashboards  
- Streams keyed by `streamToken` (TTL-limited)

---

<a name="A4"></a>
## A4. Idempotency, Rate Limits, and Concurrency

### Idempotency
- Mutating tools require `idempotencyKey`
- Store hash of normalized args → TTL 24h
- Duplicate key → return cached result

### Rate Limits
- Token bucket per `{userId}:{tool}`
- 10 RPS read, 2 RPS write typical

### Concurrency
- Redis `SETNX` lock per job
- Export concurrency: 4 local / 16 prod

### Addenda (V3.2)
- Circuit breakers (`Resilience4j`, `Polly`)
- Per-user export budgets
- Report `remainingBudget` in `export.start` result

---

<a name="A5"></a>
## A5. Storage and Artifacts
- MinIO locally; S3 prod
- Presigned URLs (TTL 15–60m)
- Validate checksum before returning

---

<a name="A6"></a>
## A6. Observability

### Metrics
```
mcp_tool_calls_total{tool="onshape.export.start"}
mcp_job_duration_seconds{tool="onshape.export"}
onshape_http_requests_total{endpoint="/exports"}
```

### Logs
```json
{"ts":"2025-10-01T13:15Z","tool":"onshape.export.start","jobId":"job-123","stage":"queued"}
```

### Traces
- Parent: `mcp.tools.call`
- Child: `onshape.http.export`
- Child: `minio.putobject`

### Dashboards
- Funnel by job stage
- Error heatmap by endpoint

### Addenda (V3.2)
- Histogram: `onshape_export_stage_latency_seconds{stage}`
- SLO alerts if error ratio >1% / 5m
- Trace links to job logs via `jobId`

---

# B) Implementation Details (Onshape-Focused)

## B1. Onshape API Binding
- Typed methods: `startExport`, `getExportStatus`, etc.
- Normalize IDs (document/workspace/element)

---

<a name="B2"></a>
## B2. Authentication & Security

### Options
1. **API Key + Secret (HMAC)**
2. **OAuth2 (user-delegated)**
3. **mTLS (internal ALB ↔ gateway)**

### Practices
- Store secrets in AWS Secrets Manager
- Encrypt refresh tokens
- Map JWT claims to policy `{sub, groups, scopes}`
- Least privilege scopes: `onshape:read.*`, `onshape:write.*`

### Logging
- Scrub PII / secrets
- Hash large argument payloads

---

<a name="B3"></a>
## B3. Request Signing (HMAC)
- Canonical string: `method + path + date + hash`
- Header: `Authorization: Onshape-HMAC keyId:signature`

---

<a name="B4"></a>
## B4. OAuth2 Flow
- Dev: Keycloak  
- Prod: Cognito / Okta / Onshape OAuth  
- Rotate keys; use client credentials or auth-code

---

<a name="B5"></a>
## B5. Java 21 Implementation

### Export Worker
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

### SSE Endpoint
```java
@GetMapping(path="/mcp/stream", produces=MediaType.TEXT_EVENT_STREAM_VALUE)
public Flux<ServerSentEvent<String>> stream(@RequestParam String token) {
  return jobEvents.byToken(token).map(ev -> ServerSentEvent.builder(ev.json()).build());
}
```

### Addenda (V3.2)
- Bucketed backoff per document
- Tenant-prefixed Redis keys

---

<a name="B6"></a>
## B6. .NET 8/9 Implementation

### Worker
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

### SSE
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

### Addenda (V3.2)
- RateLimiter middleware `{tenant}:{user}:{tool}`
- OpenTelemetry attributes: `service.name`, `tenant.id`

---

<a name="B7"></a>
## B7. Policy, Idempotency & Validation

### Policy Guard (Java)
```java
public void assertAllowed(String userId, String tool, Map<String,Object> args) {
  if (!policy.isAllowed(userId, tool)) throw new McpError(-32000, "Policy denied");
  if (tool.contains("transition") && Boolean.TRUE.equals(args.get("dryRun"))) return;
}
```

### Idempotency (.NET)
```csharp
public async Task<TResult> WithIdempotencyAsync<TResult>(string key, Func<Task<TResult>> work, TimeSpan ttl)
{
  if (await store.TryGetAsync<TResult>(key) is { } cached) return cached;
  var result = await work();
  await store.PutAsync(key, result, ttl);
  return result;
}
```

### Validation
- Reject empty collections  
- Enforce whitelists on metadata keys  
- Require `dryRun` for bulk (>1000 items)

---

# Appendix: Configuration Defaults
| Setting | Default |
|----------|----------|
| Poll Interval | 2s (max backoff 15s) |
| Export Concurrency | 4 local / 16 prod |
| Signed URL TTL | 30 minutes |
| Job TTL | 7 days |
| Heartbeat Interval | 10s |
| Circuit Breaker | 5 failures / 60s reset |
