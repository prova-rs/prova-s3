# prova-s3

A blob resource plugin for [Prova](https://github.com/prova-rs/prova) — S3-compatible object store (MinIO) — docker-exec over mc, zero native code.

A **docker-exec** plugin: zero native code. It provisions an ephemeral `minio/minio` container, waits
for readiness, and drives the CLI already in the image (`mc`) — all through Prova's
`prova.containerized` + `container:run` SDK.

## Use it

Declare the plugin in your `prova.toml`:

```toml
[plugins]
s3 = "prova-rs/prova-s3@v1"   # org/repo shorthand (fetched, pinned, cached)
```

Then in a test:

```lua
local s3 = require("s3")

local resource = prova.fixture("s3", Scope.File, function(ctx)
  return s3.container(ctx)          -- provisions, waits, attaches a client, ties teardown
end)

prova.group("example", { requires = { "docker" } }, function(g)
  g:test("does the thing", function(t)
    local r = t:use(resource)
    -- r.client:...   -- drive it
    t:expect(r.url):matches("^http://")
  end)
end)
```

Hand `r.url` (a `http://…` endpoint) to the app under test via its env, and assert the effect
either through the app's API (black-box) or directly with the client here.

## API

`s3.container(ctx, opts?)` → `{ client, url, container }`

- `url` — `http://127.0.0.1:<port>`, the endpoint for the app under test.
- `container` — the Docker handle (`:host_port`, `:run`, `:logs`, …).
- `client` — the docker-exec client (implement its methods in `s3.lua`).

`opts`: `image`, `tag` (default `latest`), `timeout` — the `prova.containerized` options.

## Requirements

Docker at test time. Gate tests with `requires = { "docker" }` so they skip cleanly where the daemon
is absent.

## Develop

```bash
prova                       # runs tests/ against ./s3.lua (needs Docker)
prova plugin lint s3.lua
```

MIT licensed.
