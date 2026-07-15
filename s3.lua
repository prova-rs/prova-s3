-- prova-s3 — an S3-compatible object store (MinIO) plugin via docker-exec over `mc` (zero native
-- code). The "blob store" container shape: multi-step client config (`mc alias set`), JSON output
-- (`mc --json`), and a stdin-piped put (`mc pipe`). `mc` ships in the server image, so we exec into
-- the provisioned container — no separate client container needed.
--
--   local minio = require("minio")
--   local blob = minio.container(ctx)                  -- { client, url, container }; default bucket "prova"
--   blob.client:put("prova", "hello.txt", "hi there")
--   blob.client:get("prova", "hello.txt")              -- "hi there"
--   blob.client:list("prova")                          -- { "hello.txt" }

-- Run `mc` inside the container via the argv form of `container:run` (no shell, no quoting). `stdin`
-- feeds `mc pipe` (the put path) through the SDK's stdin option — no shell `printf | …`.
local function mc(container, args, stdin)
  local argv = { "mc" }
  for _, a in ipairs(args) do argv[#argv + 1] = a end
  return container:run(argv, stdin ~= nil and { stdin = stdin } or nil)
end

local function make_client(container)
  local client = {}

  function client:make_bucket(name)
    mc(container, { "mb", "--ignore-existing", "local/" .. name })
    return self
  end

  function client:put(bucket, key, content)
    mc(container, { "pipe", "local/" .. bucket .. "/" .. key }, content)
    return self
  end

  function client:get(bucket, key)
    return mc(container, { "cat", "local/" .. bucket .. "/" .. key })
  end

  -- `mc --json ls` emits one JSON object per line; parse each with the SDK's `prova.parse.json`.
  function client:list(bucket)
    local keys = {}
    for _, line in ipairs(prova.parse.lines(mc(container, { "--json", "ls", "local/" .. bucket }))) do
      local obj = prova.parse.json(line)
      if obj.key then keys[#keys + 1] = obj.key end
    end
    return keys
  end

  function client:remove(bucket, key)
    mc(container, { "rm", "local/" .. bucket .. "/" .. key })
    return self
  end

  function client:close() end

  return client
end

local s3 = prova.containerized{
  name = "s3", image = "minio/minio", port = 9000, timeout = "60s",
  command = "server /data",
  env = function(opts)
    return {
      MINIO_ROOT_USER = opts.access_key or "minioadmin",
      MINIO_ROOT_PASSWORD = opts.secret_key or "minioadmin",
    }
  end,
  url = function(hp) return "http://127.0.0.1:" .. hp end,
  -- Credentials are resource fields beyond the trio (the app under test needs them to reach S3), via
  -- the `extra` hook → `resource.access_key` / `resource.secret_key`.
  extra = function(_url, opts)
    return {
      access_key = opts.access_key or "minioadmin",
      secret_key = opts.secret_key or "minioadmin",
    }
  end,
  -- The factory configures the `mc` alias (idempotent) against the server's in-container port, then a
  -- `mc ls` is the readiness gate (raises until the server answers → prova.retry loops). It also
  -- creates a default bucket for convenience.
  client = function(_url, opts, container)
    local access = opts.access_key or "minioadmin"
    local secret = opts.secret_key or "minioadmin"
    mc(container, { "alias", "set", "local", "http://localhost:9000", access, secret })
    mc(container, { "ls", "local" })
    local client = make_client(container)
    client:make_bucket(opts.bucket or "prova")
    return client
  end,
}

return s3
