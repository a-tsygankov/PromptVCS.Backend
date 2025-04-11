# PromptVCS Backend

PromptVCS is a version control system for AI prompts, designed to support experimentation, analysis, and evolution of prompts across different LLMs. This backend is built with a focus on modularity, maintainability, and extensibility using modern .NET architecture practices.

---

## ✨ Purpose

The backend supports:
- Storing prompt versions in a tree-like structure
- Branching, merging, and annotating prompt versions
- Storing LLM execution results for each prompt version
- Comparing results across LLMs and prompt variants
- Keeping visibility settings (public/private) for each version
- Supporting multiple LLMs (local and external) and execution strategies

---

## 🧠 Design Principles

- **.NET 8**
- **Domain-Driven Design (DDD)**
- **Command Query Responsibility Segregation (CQRS)**
- **Event Sourcing**
- **Repository Pattern**
- **Strongly Typed IDs**
- **Modular, Testable, Scalable**

---

## 🏗️ Project Structure

```
PromptVCS.Backend/
├── src/
│   ├── PromptVCS.API/               # ASP.NET Core Web API
│   ├── PromptVCS.Application/       # Application logic, commands, queries, Brighter handlers
│   ├── PromptVCS.Domain/            # Aggregates, entities, value objects
│   ├── PromptVCS.Infrastructure/    # Event store, repositories, adapters
│   ├── PromptVCS.Persistence/       # EF Core models, DbContext
│   ├── PromptVCS.SharedKernel/      # Base types, strongly typed IDs
│   └── PromptVCS.EventSourcing/     # Event sourcing infrastructure
│
├── tests/
│   ├── PromptVCS.UnitTests/         # Unit tests
│   └── PromptVCS.IntegrationTests/  # API & event store integration
│
├── build/
│   ├── scripts/                     # PowerShell scripts
│   └── tools/                       # Optional custom tooling
```

---

## 🔧 Implementation Details

### ✅ Strongly Typed IDs
- [StronglyTypedId](https://www.nuget.org/packages/StronglyTypedId) NuGet package
- Backing type: `Guid`
- Used for all entities (e.g., `PromptId`, `LLMId`, `PromptVersionId`)

### ✅ CQRS with Brighter
- Uses [Brighter](https://www.goparamount.com/brighter) for in-process command/query handling
- Brighter provides support for pipeline behavior, outbox pattern, and optional messaging transport
- Commands are handled by dedicated handlers; Queries return read models

### ✅ Event Sourcing
- All state changes are persisted as events
- Read models are rebuilt by projecting events
- Event store is pluggable and decoupled

### ✅ Visibility Flags
- Each prompt version has `Visibility: Public | Private`
- Defaults to private
- Inherited from parent version on creation

### ✅ LLMs as Entities
- Each model (e.g., GPT-4, Claude, Local LLMs) is stored with ID and metadata
- Execution results stored per LLM and per version

### ✅ Annotations
- Prompt versions support annotations
- Annotations can be set to propagate to child versions (configurable per annotation)

---

## 🧰 Tools & Libraries

| Tool / Library             | Purpose                                  |
|---------------------------|------------------------------------------|
| .NET 8                    | Backend framework                        |
| ASP.NET Core Web API      | API layer                                |
| Entity Framework Core     | Persistence (for projections and data)   |
| StronglyTypedId           | Source-generated ID wrappers             |
| Brighter                  | CQRS, command and event dispatching      |
| xUnit / NUnit             | Testing                                  |
| Serilog (planned)         | Logging                                  |
| Swashbuckle / Swagger     | API documentation                        |

---

## 💻 Development

### Requirements
- .NET 8 SDK
- Git
- PowerShell 5.1+ (or Windows Terminal)
- Local PostgreSQL / SQLite (optional for persistence)

### Setup
Run PowerShell setup script (if not already initialized):

```powershell
.uild\scripts\setup-promptvcs.ps1
```

### Run Web API

```powershell
cd src/PromptVCS.API
dotnet run
```

---

## 🧪 Testing

```powershell
dotnet test tests/PromptVCS.UnitTests
dotnet test tests/PromptVCS.IntegrationTests
```

---

## 📄 License

MIT (or TBD)

---

## 🧭 Roadmap

- [ ] Domain modeling (Prompt, PromptVersion, LLM, Execution)
- [ ] Event sourcing foundation
- [ ] CQRS using Brighter
- [ ] EF Core persistence and projections
- [ ] Visibility + branching
- [ ] Result comparison engine
- [ ] GitHub Actions integration
