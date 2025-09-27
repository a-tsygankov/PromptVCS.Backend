# .NET Backend Engineering Playbook 
*Practical, AI-assistant-friendly standards for modern C#/.NET teams (humans + tools like Cursor/Windsurf). Builds on your existing “.NET Backend Architecture & Development Standards.”*

---

## 0) Why this document?

- **For humans:** concrete, example-driven rules that reduce bikeshedding and defects. 
- **For AI tools (Cursor, Windsurf, etc.):** guardrails and scaffolds so generated code is consistent, testable, and production-ready. 
- **For the repo:** a single source of truth you can link in PR templates, prompts, and CI.

---

## 1) Architecture Principles (recap + refinements)

- **DDD, Aggregates, Strongly-Typed IDs, CQRS, Event Sourcing** remain foundational. Use them **when they reduce complexity**; avoid ceremony for simple CRUD.
- **Hexagonal / Clean Architecture:** Domain independent of frameworks. Adapters at edges (HTTP, DB, Message Bus).
- **Evented thinking everywhere:** Prefer *raise handle project* to cascading synchronous calls.
- **Async by default:** Avoid sync-over-async. All I/O boundaries are `async`.
- **Evolution, not revolution:** Prefer additive changes, feature flags, and reversible migrations.

> Decision rule:** If the change touches more than one bounded context or cross-cutting concerns, open an ADR (Architecture Decision Record).

---

## 2) Practical SOLID + Clean Code (straight to the point)

- **Single Responsibility:** One reason to change. Extract small, nameable policies; pass via DI.
- **Open/Closed:** New behaviors via new classes/strategies, not `if` ladders.
- **Liskov:** Don’t weaken postconditions/strengthen preconditions in subclasses; prefer composition.
- **Interface Segregation:** Narrow interfaces (`IClock`, `IIdGenerator`, `IEventPublisher`).
- **Dependency Inversion:** High-level depends on abstractions; wire concretions at composition root.

**Clean Code:** 
- Small files (≤300 LOC) and methods (≤20–30 LOC). 
- State the intent in names; remove comments that explain *what*, keep comments that explain *why*. 
- Fail fast; check invariants at boundaries; never return half-valid objects. 
- Eliminate duplication; prefer pure functions for transformations.

---

## 3) Source Layout & Naming

```
/src
 /Api // HTTP endpoints, filters, ProblemDetails
 /Application // Commands, Queries, Validators, DTO mappers
 /Domain // Aggregates, Entities, ValueObjects, domain services, events
 /Infrastructure // EF Core, EventStore, Outbox, Bus, External services
 /SharedKernel // Base abstractions, StronglyTyped IDs, Result types, Errors
/tests
 /Unit
 /Integration
 /Contract // Pact/contract tests if applicable
```

- Namespace = folder path. 
- Suffixes: `…Controller`, `…Endpoint`, `…Handler`, `…Validator`, `…Repository`, `…Projection`. 
- IDs are strongly typed (`OrderId`, `ModelId`, etc.) and never raw `Guid` beyond the boundary.

---

## 4) Coding Standards (C#/.NET 8+)

- **Language:** latest C#; `var` when obvious; target-typed `new`; primary constructors when helpful. 
- **Nullability:** enabled in projects that can; otherwise treat nulls as exceptional and guard at edges. 
- **Records & immutability:** Use for VOs and DTOs; aggregates keep private setters + explicit methods. 
- **Pattern matching** over `if` chains; switch expressions for small policy maps. 
- **Collections:** Prefer `IReadOnlyList<T> /`IReadOnlyDictionary<T> for outputs. 
- **Errors:** Don’t throw for control flow. Return `Result<T, Error> (or ProblemDetails at HTTP). 
- **Logging:** Structured (message + properties). No string interpolation for dynamic fields. 
- **Asynchrony:** Propagate `CancellationToken`. Avoid `Task.Result` / `.Wait()`.

**Formatting & analyzers (required):** 
- `.editorconfig` + `dotnet format` in CI. 
- Roslyn analyzers + StyleCop (treat warnings as errors). 
- No pragma suppression unless justified in code comment with issue link.

---

## 5) API Design (HTTP)

- **Resource first:** `/v1/models/{id}`, `/v1/prompts/{id}/versions`. 
- **Status codes:** `200/201/202/204/400/401/403/404/409/422/429/5xx`. 
- **ProblemDetails** for errors (include `traceId`, `code`, `details`). 
- **Validation:** FluentValidation at request boundary; domain invariants inside aggregates. 
- **Pagination:** `?page[size]=…&page[number]=…` + `X-Total-Count`. 
- **Idempotency:** For creates that can be retried, support `Idempotency-Key`. 
- **Versioning:** URL or header; never break v1 once released. 
- **OpenAPI/Swagger:** Always live; examples + XML docs; hide internal endpoints.

---

## 6) Persistence & Data

- **EF Core for reads/projections; Event Store for writes** (if event-sourced). 
- **Migrations:** one per PR topic; name with intent; zero ad-hoc SQL in code. 
- **Outbox pattern:** all domain events to outbox within same transaction; background dispatcher publishes. 
- **Projections:** Async, idempotent, replayable; keep checkpointing; no business decisions in projections. 
- **Caching:** App-level for reference data; HTTP caching headers for GETs; cache busting via ETag if needed.

---

## 7) Messaging & Integration

- **Contracts:** version messages; never break consumers. Include message `type`, `id`, `occurredAt`. 
- **At-least-once delivery:** Handlers must be idempotent; use message de-duplication. 
- **Retries:** bounded with jitter; poison queue after N attempts. 
- **Resilience:** Polly policies at edges (timeouts, retries, circuit breakers).

---

## 8) Security & Compliance

- **AuthZ:** Policy-based; claims mapped to roles/permissions. 
- **Secrets:** Managed via platform secret store; never in appsettings. 
- **Input handling:** Validate length, regex, and enums; reject unknown fields (model binding). 
- **PII:** Tag PII fields; log hashes or redacted values only. 
- **HTTPS everywhere;** HSTS; secure headers (CSP, X-Content-Type-Options, etc.). 
- **Audit:** Append-only audit log for sensitive actions; include actor, resource, before/after.

---

## 9) Observability

- **Logging:** Serilog with sinks (console + JSON). Correlate `traceId` across services. 
- **Metrics:** Prometheus/OpenTelemetry (requests, errors, latency, queue lengths). 
- **Tracing:** OTel tracing around I/O, bus, DB; sample rates controlled via config. 
- **Health:** Liveness (`/healthz`), readiness (`/readyz`), startup probes.

---

## 10) Testing Strategy (automation-first)

- **Unit:** Pure, fast, deterministic; cover domain rules and handlers. 
- **Integration:** Test adapters (DB, bus, HTTP) with real infra via containers. 
- **Contract:** Provider/consumer pacts or schema checks for messages and HTTP. 
- **End-to-end (optional):** Smoke workflows behind feature flags. 
- **Test data:** Builders/AutoFixture; avoid magic constants; freeze time via `IClock`.

**Coverage gate:** meaningful threshold (e.g., 80%)—but **no gaming**: measure diff coverage per PR.

---

## 11) Performance

- **Budget per endpoint:** latency SLO + memory allocations target. 
- **Allocations:** prefer pooled arrays, spans and `ArrayPool<T> for hot paths. 
- **I/O:** batching where possible; avoid N+1 (query plans verified). 
- **Benchmarking:** BenchmarkDotNet for critical code paths; publish results in PR.

---

## 12) CI/CD & Branching

- **Branching:** `main` always deployable; feature branches PRs; short-lived. 
- **Commits:** Conventional Commits (`feat:`, `fix:`, `refactor:`, `test:` …). 
- **PR template:** checklist (tests, docs, migration, ADR link, breaking changes). 
- **Pipelines:** 
 1. restore build analyzers tests (unit/integration) `dotnet format --verify-no-changes` 
 2. package SBOM sign deploy to staging smoke promote 
- **Envs:** Dev/Staging/Prod parity; config via env vars or appsettings.*.json overlays.

---

## 13) AI-Assistant-Friendly Conventions (Cursor, Windsurf, etc.)

- **Scaffolding blocks:** 
 - `// <auto-generated> DO NOT EDIT. See generator config.</auto-generated> 
 - `// BEGIN-CUSTOM` / `// END-CUSTOM` regions for hand-written code. 
- **Prompt-readable files:** Keep **small, focused files** and **clear folder names** so AIs infer patterns. 
- **Deterministic templates:** Keep ready-to-copy examples (below) so tools can “paste then adapt.” 
- **Spec first:** Put a short **docstring** atop handlers/endpoints describing inputs, side effects, idempotency. 
- **Validation hints:** Keep FluentValidation classes close to request DTOs so assistants pick them up. 
- **Guardrails:** Add analyzer rulesets and nullable context so assistants generate safer code. 
- **Checklists in code:** 
 ```csharp
 // HANDLER CHECKLIST: validate authorize load aggregate act raise events persist publish outbox
 ```
- **Small diffs:** Prefer micro-PRs—AI reviews are better with focused context.

---

## 14) Ready-to-Copy templates

### 14.1 `.editorconfig` (excerpt)
```ini
root = true

[*.cs]
dotnet_diagnostic.SA0001.sealty = warning
dotnet_diagnostic.CA2000.severity = error
csharp_style_var_when_type_is_apparent = true:error
dotnet_style_qualification_for_field = false:suggestion
dotnet_style_prefer_auto_properties = true:suggestion
dotnet_style_null_propagation = true:suggestion
dotnet_style_prefer_is_null_check_over_reference_equality_method = true:suggestion
```

### 14.2 `Directory.Build.props` (hardened)
```xml
<Project> 
 <PropertyGroup> 
 <TargetFramework> net8.0</TargetFramework> 
 <ImplicitUsings> enable</ImplicitUsings> 
 <Nullable> enable</Nullable> 
 <TreatWarningsAsErrors> true</TreatWarningsAsErrors> 
 <LangVersion> preview</LangVersion> 
 <Deterministic> true</Deterministic> 
 <ContinuousIntegrationBuild> true</ContinuousIntegrationBuild> 
 <GenerateDocumentationFile> true</GenerateDocumentationFile> 
 </PropertyGroup> 
 <ItemGroup> 
 <PackageReference Include="Serilog.AspNetCore" Version="8.*" /> 
 <PackageReference Include="FluentValidation.AspNetCore" Version="11.*" /> 
 <PackageReference Include="Paramore.Brighter" Version="9.*" /> 
 <PackageReference Include="StronglyTypedId" Version="1.*" /> 
 </ItemGroup> 
</Project> 
```

### 14.3 ProblemDetails factory
```csharp
app.UseExceptionHandler(a => a.Run(async ctx => 
{
 var feature = ctx.Features.Get<IExceptionHandlerFeature> ()!;
 var problem = new ProblemDetails
 {
 Title = "Unexpected error",
 Status = StatusCodes.Status500InternalServerError,
 Detail = "An error occurred. Contact support with traceId.",
 Instance = ctx.Request.Path
 };
 problem.Extensions["traceId"] = Activity.Current?.TraceId.ToString() ?? ctx.TraceIdentifier;
 await Results.Problem(problem).ExecuteAsync(ctx);
}));
```

### 14.4 CQRS Command handler skeleton
```csharp
public sealed record CreateModelCommand(ModelName Name) : IRequest<Result<ModelId, Error> > ;

public sealed class CreateModelHandler(IClock clock, IIdGenerator idGen, IEventStore store)
 : IRequestHandler<CreateModelCommand, Result<ModelId, Error> > 
{
 public async Task<Result<ModelId, Error> > Handle(CreateModelCommand cmd, CancellationToken ct)
 {
 // validate
 if (string.IsNullOrWhiteSpace(cmd.Name.Value))
 return Error.Validation("name.empty").ToResult<ModelId> ();

 var id = new ModelId(idGen.New());
 var evt = new ModelCreated(id, cmd.Name, clock.UtcNow());

 await store.AppendAsync(id.Value, expectedVersion: null, events: [evt], ct);
 return id;
 }
}
```

### 14.5 Outbox dispatcher loop (idempotent)
```csharp
while (!ct.IsCancellationRequested)
{
 var batch = await outbox.FetchUnpublishedAsync(100, ct);
 foreach (var msg in batch)
 {
 var published = await bus.TryPublishAsync(msg.Topic, msg.Payload, ct);
 if (published) await outbox.MarkPublishedAsync(msg.Id, ct);
 }
 await Task.Delay(TimeSpan.FromSeconds(1), ct);
}
```

---

## 15) Code Review Checklist (paste into PR template)

- [ ] Tests added/updated (unit, integration, or contract as appropriate) 
- [ ] Public API documented; OpenAPI updated 
- [ ] Logging structured; no sensitive data logged 
- [ ] Validation & authorization at boundaries 
- [ ] Exceptions translated to ProblemDetails 
- [ ] No blocking analyzer warnings; `dotnet format` clean 
- [ ] Migrations present & reversible; seeds idempotent 
- [ ] ADR added/updated if architectural decision changed

---

## 16) Prompts & Usage with AI Tools

- **“Generate a new Aggregate”** Provide: invariant list, commands/events, ID type, repository policy, validation rules. 
- **“Create endpoint”** Provide: route, request/response, auth policy, idempotency needs, ProblemDetails map, tests. 
- **“Refactor handler”** Provide: size goals, extracted policies, acceptance tests to keep green.

> Keep prompts **short + structured**; paste nearby examples so AIs follow house style.

---

## 17) Governance & Lifecycle

- **ADR folder:** `/docs/adr/YYYY-MM-DD-title.md` (status: proposed/accepted/superseded). 
- **Deprecation policy:** mark deprecated endpoints with response warning headers, add timeline, provide migration steps. 
- **Release notes:** generated from Conventional Commits; call out breaking changes and migration guides.

---

## 18) Onboarding Quick Start

1. Read this playbook + last 3 ADRs. 
2. Clone repo run `./build.ps1 bootstrap`. 
3. Run `dotnet test` (all green) `dotnet run --project src/Api`. 
4. Open Swagger, try the smoke endpoints. 
5. Pick a good first issue: “good first issue” or “help wanted”.

---

### Final Notes

- This playbook **extends** your existing standards; keep both documents in the repo and link between them. 
- Treat it as living: update alongside code; open small PRs with examples. 
- If something isn’t covered, prefer **consistency over novelty**—copy an existing, good pattern.

---

# Appendix A: DDD, CQRS, Event Sourcing Foundations (Expanded)

# .NET Backend Engineering Playbook – Foundations (Expanded)

This update breaks down the guidance:
> DDD, Aggregates, Strongly‑Typed IDs, CQRS, Event Sourcing** remain foundational. Use them **when they reduce complexity**; avoid ceremony for simple CRUD.

The goal is pragmatic: **apply each technique only where it makes the system simpler, safer, and easier to evolve.**

---

## 1) DDD & Aggregates (when and how)

### When to use DDD
Use DDD when at least one is true:
- Complex domain rules/invariants (ordering, limits, pricing, quotas, eligibility).
- Multiple workflows collide on the same data (race conditions, concurrency).
- You need a ubiquitous language with domain experts.
- Future changes are frequent and hard to localize.
Skip full DDD for simple CRUD or reporting modules; prefer “thin services + rich database” there.

### Aggregate checklist
An **Aggregate** is a transactional consistency boundary controlled by a root entity.

- **Root:** Only the root is loaded/saved directly (`Order`, `Invoice`, `ModelDefinition`).
- **Invariants:** Encoded in methods on the root (e.g., `Order.AddLine(...)` validates stock, limits, and state).
- **Encapsulation:** Child entities are changed **only** through the root’s methods.
- **Size:** Prefer small aggregates that can be updated in one transaction; avoid “kitchen‑sink” roots.
- **IDs:** Always strongly‑typed (see §3). Expose behavior, not setters.
- **Factories:** Creation via domain methods or factories that enforce invariants.
- **Concurrency:** Use optimistic concurrency (row version / event version). Do not merge conflicting decisions silently.
- **Events:** Methods return or raise **domain events** (e.g., `OrderLineAdded`, `OrderShipped`), persisted or published via outbox.

### Example (sketch)
```csharp
public sealed class Order : Aggregate<OrderId> 
{
 private readonly List<OrderLine> lines = [];
 public IReadOnlyList<OrderLine> Lines => lines;

 public void AddLine(ProductId productId, int qty, Money unitPrice, IClock clock)
 {
 if (State != OrderState.Draft) throw DomainError.State("order.not-draft");
 if (qty <= 0) throw DomainError.Validation("qty.positive");
 _lines.Add(new OrderLine(productId, qty, unitPrice));
 Raise(new OrderLineAdded(Id, productId, qty, unitPrice, clock.UtcNow()));
 }

 public void Confirm(IStockService stock, IClock clock)
 {
 foreach (var l in _lines) stock.EnsureAvailable(l.ProductId, l.Qty);
 State = OrderState.Confirmed;
 Raise(new OrderConfirmed(Id, clock.UtcNow()));
 }
}
```

---

## 2) Strongly‑Typed IDs (safety at boundaries)

### Why
- Prevents mixing IDs across entities at compile time.
- Encourages **pure domain APIs** (`OrderId`, `UserId`, `ModelId`) instead of `Guid`/`string` everywhere.
- Encodes creation policy (GUID/ULID/snowflake) in one place.

### Practical rules
- Only **convert to primitives at I/O edges** (HTTP, DB, messages).
- Implement equality, `ToString()`, and type converters once and reuse.
- Provide a single **ID factory** (`IIdGenerator`) per service.
- Choose an ID kind based on scale/infra:
 - **GUID v4**: simplest; collision‑safe; unordered.
 - **COMB/Sequential GUID / NewId**: index‑friendly for DBs that hate random GUID order.
 - **ULID**: readable, sortable by time; great for logs and distributed systems.
 - **Snowflake‑style**: time + worker + sequence; works well at very high scale.

### Suggested libraries
- **StronglyTypedId** (source generator): ergonomic, minimal boilerplate.
- **MassTransit.NewId**: sequential, high‑entropy GUIDs for DB friendliness.
- **NUlid** or **Ulid**: ULID implementations.
- **IdGen**: Snowflake‑like IDs configurable for your cluster.
> You may also roll a minimal source generator if you want zero deps; keep it in `/SharedKernel/Ids`.

### Example
```csharp
[StronglyTypedId(StronglyTypedIdBackingType.Guid, "json")]
public partial struct OrderId { }

public interface IIdGenerator { Guid New(); } // or Ulid NewUlid();
```

---

## 3) CQRS (UI and backend)

**Command Query Responsibility Segregation** = separate write models (commands that change state) from read models (queries optimized for reads).

### When to use
- Read patterns differ from write patterns (e.g., complex filtering, dashboards).
- You need **fast UI lists** and **rich invariants** in commands.
- Event sourcing: projections naturally implement read models.

Avoid CQRS for small modules where the mental overhead doesn’t pay off.

### UI patterns
- **Reads:** UI talks to **query endpoints** (lightweight DTOs, joining/projection allowed). Cache and paginate.
- **Writes:** UI sends **commands** (minimal data, intent‑centric). Avoid leaking persistence DTOs into UI.
- **Latency:** Consider **async confirmation** (202 Accepted + polling) for long processes.
- **Idempotency:** UI passes `Idempotency-Key` for “create” to avoid dupes on retry.

### Backend patterns
- **Application layer**: `IRequestHandler<TCommand, Result> and `IRequestHandler<TQuery, TDto> (MediatR/Brighter/etc.).
- **Validation**: FluentValidation for commands/queries at the boundary + domain invariants inside aggregates.
- **Transactions**: One transaction per command; queries are read‑only and may hit replicas.
- **Read models**: Fit‑for‑purpose tables or document views; updated via projections or application services.

### Example
```csharp
// Command
public sealed record ConfirmOrder(OrderId OrderId) : IRequest<Result<Success, Error> > ;

// Query
public sealed record GetOrderList(int Page, int Size) : IRequest<PagedResult<OrderListItem> > ;

// Controller
[HttpPost("orders/{id}/confirm")]
public Task<IResult> Confirm(OrderId id, IMediator mediator, CancellationToken ct)
 => mediator.Send(new ConfirmOrder(id), ct).ToHttpResult();

[HttpGet("orders")]
public Task<PagedResult<OrderListItem> > List([FromQuery] int page, [FromQuery] int size, IMediator mediator, CancellationToken ct)
 => mediator.Send(new GetOrderList(page, size), ct);
```

---

## 4) Event Sourcing (auditability and evolution)

### When to use
- You **must** reconstruct past state or investigate decisions (compliance/audit).
- Domain language is naturally event‑driven (approval flows, lifecycle changes).
- You want **temporal queries** (“as of” reports) or time‑based analytics.

Avoid event sourcing for **static, CRUD‑heavy** modules; projections add operational burden.

### Core rules
- **Aggregate state = fold(events)**; the write model stores only events.
- **Each event is immutable**, schema‑versioned, and carries minimal but sufficient facts.
- **Versioning**: add events (append‑only) rather than mutating old ones; evolve read models via re‑projection.
- **Idempotency**: use expected version on append; handle duplicate deliveries in projections.
- **Event store choices**: EventStoreDB, Marten (PostgreSQL), SQL stream tables, or custom append‑only tables.
- **Projections**: run in background; must be **replayable** and **idempotent** with checkpointing.

### Example (minimal sketch)
```csharp
public sealed class OrderState
{
 public static OrderState Empty => new();
 public OrderState Apply(object evt) => evt switch
 {
 OrderCreated e => this with { Id = e.Id, State = Draft },
 OrderConfirmed => this with { State = Confirmed },
 OrderShipped => this with { State = Shipped },
 _ => this
 };
}
```

---

## 5) Event Choreography (distributed or modular monolith)

**Goal:** decouple modules/services using **domain events** and **outbox** so each module reacts independently.

### Choreography vs Orchestration
- **Choreography**: services publish events; others react (loose coupling, emergent flows). Great for small teams and clear domain events.
- **Orchestration**: a coordinator (saga) commands services (explicit process manager). Prefer when steps and compensations are complex.

### Rules for choreography
- **Outbox pattern**: publish events from the same transaction as the state change; a dispatcher sends them to the bus.
- **Contracts**: version events; never break subscribers. Include `type`, `occurredAt`, `id`, `schemaVersion`.
- **Idempotent handlers**: de‑duplicate by event id + consumer id; use transactional inbox when supported.
- **Retries + DLQ**: bounded retries with jitter; poison queue after N attempts.
- **Modular monolith**: use in‑process bus (e.g., Brighter, MediatR notification) + outbox only when leaving the process.
- **Observability**: correlate `traceId`; measure handler success/failure; expose consumer lag metrics.

### Example event flow (pseudo)
```
OrderConfirmed -> published to outbox
Outbox dispatcher -> message bus topic 'orders.confirmed'
Billing service consumes -> AuthorizePayment command
Shipping service consumes -> PrepareShipment command
Email service consumes -> SendConfirmationEmail
```

### Compensations
- When an action fails downstream, publish **compensating events** (e.g., `PaymentFailed`) that trigger remedial actions (`OrderUnconfirmed`, `RefundAuthorized`). Use orchestration if the graph becomes too intricate to reason about.

---

## 6) Choosing the right tool for the job

| Technique | Use it when | Avoid it when | Cost to operate |
|---|---|---|---|
| DDD + Aggregates | Rich rules, collisions, evolving language | Simple CRUD/reporting | Low‑medium |
| Strongly‑Typed IDs | Many entity types; safety at compile time | One or two tables total | Very low |
| CQRS | Different read/write shapes; dashboards; ES | Small modules; trivial lists | Low‑medium |
| Event Sourcing | Auditability, time travel, explainability | Static/reference data | Medium‑high |
| Event Choreography | Teams/modules evolve independently | Highly coupled, complex processes | Medium |

> Rule of thumb:** Start simple; add sophistication **only** when pain becomes real. Use feature flags to migrate safely.

---

## 7) Minimal scaffolding (ready to paste)

```csharp
// ID
[StronglyTypedId(StronglyTypedIdBackingType.Guid, "json")]
public partial struct ModelId { }

// Command
public sealed record CreateModel(string Name) : IRequest<Result<ModelId, Error> > ;

// Handler
public sealed class CreateModelHandler(IEventStore store, IIdGenerator ids, IClock clock)
 : IRequestHandler<CreateModel, Result<ModelId, Error> > 
{
 public async Task<Result<ModelId, Error> > Handle(CreateModel cmd, CancellationToken ct)
 {
 if (string.IsNullOrWhiteSpace(cmd.Name))
 return Error.Validation("name.empty").ToResult<ModelId> ();

 var id = new ModelId(ids.New());
 var created = new ModelCreated(id, cmd.Name, clock.UtcNow());
 await store.AppendAsync(stream: id.ToString(), expectedVersion: null, events: new object[] { created }, ct);
 return id;
 }
}

// Projection (read model)
public sealed class ModelListProjection : IProjection
{
 public Task When(ModelCreated e, CancellationToken ct)
 => db.ExecuteAsync("insert into model_list(id, name, created_at) values (@Id,@Name,@At)",
 new { Id = e.Id, Name = e.Name, At = e.OccurredAt }, ct);
}
```

---

### References you may adopt (swap per stack)
- Event store: **EventStoreDB**, **Marten**, or custom append‑only in SQL (plus checkpoints table).
- Bus: **RabbitMQ**, **Kafka**, **Azure Service Bus**. In modular monolith, **in‑proc notifications** + outbox when crossing boundaries.
- IDs: **StronglyTypedId**, **NewId**, **Ulid/NUlid**, **IdGen**.

---

**Appendix:** Integration checklist
- [ ] Aggregate methods enforce invariants and raise events
- [ ] Commands are intent‑centric and validated
- [ ] Queries are thin and fast; read models are tailored
- [ ] Outbox enabled for all state‑changing operations
- [ ] Handlers idempotent; retries bounded; DLQ configured
- [ ] Correlation/tracing across event flow