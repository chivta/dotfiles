---
name: golang-conventions
description: Personal Go/Golang style and library conventions — naming, package naming, dependency wiring, error handling (sentinel errors, AppError), graceful shutdown, Gin, go-playground/validator, zerolog, pgx/tern migrations, config, and Docker build stages for Go binaries. Use whenever writing, reviewing, or refactoring Go code, or making a Go-specific technical decision.
---

# Go Style Guide

Go-specific conventions: naming, default libraries to chose, and the concrete mechanics of error handling, wiring, logging, and data access.

**This skill does not decide structure.** Where seams go, how many packages a feature gets, how deep a module should be, and what belongs behind an interface are design questions — use `codebase-design`. What follows assumes those decisions are already made.

## Package and File Naming

**Package names** are lowercase, single word where possible. The package name is part of the interface — `spotify.Client`, not `spotifyclient.SpotifyClient`.

**File names** describe what's in them, lowercase with underscores: `auth.go`, `refresh_token.go`. Tests sit next to the code as `_test.go`.

## Interfaces

Interfaces are satisfied implicitly, so declare them where they are consumed, not where they are implemented:

```go
type userRepo interface {
    GetByID(ctx context.Context, id int64) (domain.User, error)
}
```

The concrete `*PostgresUserRepo` has no knowledge of this interface. Unexported, camelCase, descriptive noun.

Accept interfaces, return structs. Whether a given dependency deserves an interface at all is a `codebase-design` question.

## Dependency Wiring

No reflection-based DI framework. Wiring is explicit, in one place:

**Option A — container struct in `main.go`** (larger services, many components):

```go
type appContainer struct {
    db       *pgxpool.Pool
    redis    *redis.Client
    userRepo *repository.UserRepo
    authSvc  *services.AuthService
}
```

**Option B — `server.Run()` function** (smaller services where a container struct is overkill):

```go
func Run(cfg Config) error {
    db := mustConnectDB(cfg.DatabaseURL)
    repo := repository.New(db)
    svc := services.New(repo)
    // ...
}
```

Either way the full dependency graph is visible in one file without tooling, and nothing is wired implicitly.

## Types

Beyond plain structs, reach for:

- **Semantic types** — `type SortDirection string` with constants `SortAsc`, `SortDesc` beats bare strings everywhere.
- **Parameter structs** — `ListParams`, `FilterParams` instead of long argument lists that churn.
- **Constructors that enforce invariants** — `NewCountry(name string) (Country, error)` when a type can be constructed wrong.

## Error Handling

**Sentinel errors** represent expected, handled conditions:

```go
var (
    ErrNotFound      = &AppError{Status: 404, Code: "NOT_FOUND"}
    ErrUnauthorized  = &AppError{Status: 401, Code: "UNAUTHORIZED"}
    ErrQuotaExceeded = &AppError{Status: 429, Code: "QUOTA_EXCEEDED"}
)
```

`AppError` carries an HTTP status and a machine-readable code, never a human message.

**Translate errors where you know the vocabulary.** Code that talks to pgx knows `pgx.ErrNoRows` and turns it into a sentinel; code that writes HTTP responses knows `*AppError` and turns it into a status. Neither knows the other's vocabulary:

```go
if errors.Is(err, pgx.ErrNoRows) {
    return domain.ErrNotFound
}
```

Wrap with `fmt.Errorf("...: %w", err)` when adding context, or pass through unchanged.

**Never** `errors.New("some string")` inline for an error a caller is expected to handle — those are sentinels.

**Log once**, where the error is handled, with context fields. Not at every level it passes through.

Use `errors.Is` and `errors.As`, never string comparison on `err.Error()`.

## No Inline Assignment in if 
Never call a function with more than one return value inside an `if` condition. Assign results to variables first, then check on a separate line.

```go
// correct
if !isInputValid(input) {
    ...
}

// correct
res, err := doStuff(input)
if err != nil {
    ...
}

// wrong
if res, err := doStuff(input); err != nil {
    ...
}

// wrong
if res, ok := getResult(input); !ok {
    ...
}
```

## Signal Handling and Graceful Shutdown

Every long-lived process handles OS signals:

```go
ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
defer stop()
```

Pass `ctx` to the server, workers, and consumers. HTTP servers call `Shutdown(ctx)`, not `Close()`. Queue consumers and background workers select on `ctx.Done()` in their main loop. The process exits only after every component has acknowledged cancellation.

## HTTP: Gin

Use Gin. Route groups for versioning and auth; middleware registered on the group, not individual routes.

A single `RespondWithError(c *gin.Context, err error)` handles all error responses — `errors.As` for `*AppError`, 500 otherwise. Handlers never format error JSON by hand.

Bind with `ShouldBindJSON` / `ShouldBindUri` / `ShouldBindQuery`, then validate immediately.

## Validation: go-playground/validator

Declared on input structs with tags:

```go
type createUserRequest struct {
    Email    string `json:"email"    validate:"required,email"`
    Password string `json:"password" validate:"required,min=8"`
}
```

Validate at the system boundary before anything else; on failure return `400` immediately. Custom validators are registered once at startup — never `validator.New()` inside a handler.

## Logging: Zerolog

Initialized once in `main()`, used via the global logger, never injected into structs. Metrics follow the same pattern — package-level functions, not a dependency.

```go
zerolog.TimeFieldFormat = zerolog.TimeFormatUnix
log.Logger = log.With().Timestamp().Caller().Logger()
zerolog.SetGlobalLevel(zerolog.InfoLevel)
```

Always key-value fields, never interpolation:

```go
// correct
log.Error().Err(err).Str("user_id", id).Msg("failed to fetch user")

// wrong
log.Error().Msgf("failed to fetch user %s: %v", id, err)
```

## Database: pgx and tern

`pgxpool.Pool` for all database access. Never `database/sql` with a pgx driver shim — use the native pgx API.

SQL is written as plain strings. No query builder. Long queries live in named constants or their own file.

Repository types are per-entity, not one monolith — `ArtistRepo`, `TrackRepo`, each holding the pool. A caller that only reads artists then can't reach a method that writes tracks.

Migrations use tern (`jackc/tern`) with SQL files embedded via `//go:embed`, run automatically on startup:

```go
//go:embed migrations/*.sql
var migrations embed.FS

migrator, _ := migrate.NewMigrator(ctx, conn, "schema_version")
migrator.LoadMigrations(migrations)
migrator.Migrate(ctx)
```

Files are named with a zero-padded sequence: `001_create_users.sql`, `002_add_refresh_tokens.sql`. Never renumber or edit an applied migration — add a new one.

## Configuration

A `Config` struct per service, validated with `go-playground/validator`:

```go
type Config struct {
    DatabaseURL string `env:"DATABASE_URL" validate:"required,url"`
    JWTSecret   string `env:"JWT_SECRET"   validate:"required,min=32"`
}
```

Load from environment with `godotenv` (reads `.env` if present, falls back to OS env). Validate immediately, fail fast and loudly. Once validated, never recheck those values.

## Containers

Go-specific detail for the Dockerfile stages in `CLAUDE.md`:

- **Dev stage**: Alpine base, hot-reload via `air`, source bind-mounted — no rebuild on code changes.
- **Builder stage**: `CGO_ENABLED=0`, static binary, `-ldflags="-s -w"`.
- **Production stage**: `scratch` or distroless when the binary is self-contained; Alpine when a shell or `wget` is needed for a healthcheck.

## Naming

| Construct | Convention |
|---|---|
| Package | lowercase, single word |
| Exported type | PascalCase |
| Unexported interface (at consumer) | camelCase, descriptive noun |
| Constructor | `New<Type>` |
| Sentinel error | `Err<Description>` |
| Receiver | short, type-initial: `(s *Service)`, `(r *Repo)` |
| Method / function | camelCase |
| Constant | PascalCase; UPPER_SNAKE_CASE only for env-variable-derived values |

## Miscellaneous

- `context.Context` is always the first parameter of any function that does I/O.
- Avoid global mutable state outside the logger and metrics registry.
- Prefer table-driven tests when testing multiple cases of the same function.