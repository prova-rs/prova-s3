-- The prova-s3 proof suite: every exported client verb (make_bucket/put/get/list/remove), the
-- resource trio + credential extras, content fidelity through the stdin-piped put, and the
-- options surface (custom bucket + credentials) — all against a real MinIO container.
-- Requires docker; skips otherwise.

local blob = prova.fixture("s3", Scope.File, function(ctx)
  return require("s3").container(ctx)
end)

-- A second container proving the options surface: custom default bucket and credentials.
local custom = prova.fixture("s3-custom", Scope.File, function(ctx)
  return require("s3").container(ctx, {
    bucket = "artifacts", access_key = "orgadmin", secret_key = "orgsecret1",
  })
end)

prova.group("s3", { requires = { "docker" } }, function(g)
  g:test("put/get/list/remove round-trips an object", function(t)
    local c = t:use(blob).client
    c:put("prova", "hello.txt", "hi there")
    t:expect(c:get("prova", "hello.txt")):equals("hi there")

    c:put("prova", "second.txt", "more")
    local keys = c:list("prova")
    t:expect(#keys):equals(2)

    c:remove("prova", "hello.txt")
    t:expect(#c:list("prova")):equals(1)
    c:remove("prova", "second.txt")
  end)

  g:test("put preserves content byte-for-byte through the stdin pipe", function(t)
    local c = t:use(blob).client
    local content = 'line one\nline "two" with quotes\n\ttabbed — unicode: ✓\n'
    c:put("prova", "fidelity.txt", content)
    t:expect(c:get("prova", "fidelity.txt")):equals(content)
    c:remove("prova", "fidelity.txt")
  end)

  g:test("put overwrites: the latest content wins", function(t)
    local c = t:use(blob).client
    c:put("prova", "versioned.txt", "first")
    c:put("prova", "versioned.txt", "second")
    t:expect(c:get("prova", "versioned.txt")):equals("second")
    t:expect(#c:list("prova")):equals(1)   -- an overwrite is not a new key
    c:remove("prova", "versioned.txt")
  end)

  g:test("make_bucket creates on demand and is idempotent", function(t)
    local c = t:use(blob).client
    c:make_bucket("fresh")
    t:expect(c:list("fresh")):equals({})   -- exists and empty
    c:make_bucket("fresh")                 -- --ignore-existing: no error on re-create
    c:put("fresh", "a.txt", "a")
    t:expect(c:list("fresh")):equals({ "a.txt" })
    c:remove("fresh", "a.txt")
  end)

  g:test("url and credentials are exposed for the app under test", function(t)
    local r = t:use(blob)
    t:expect(r.url):matches("^http://")
    t:expect(r.access_key):equals("minioadmin")   -- an `extra` resource field beyond the trio
    t:expect(r.secret_key):equals("minioadmin")
  end)
end)

prova.group("s3 with custom options", { requires = { "docker" } }, function(g)
  g:test("a custom default bucket and credentials are honored end-to-end", function(t)
    local r = t:use(custom)
    t:expect(r.access_key):equals("orgadmin")
    t:expect(r.secret_key):equals("orgsecret1")
    -- The factory pre-created the custom default bucket; the client is aliased with the
    -- custom credentials, so a round-trip proves both were plumbed through.
    r.client:put("artifacts", "build.log", "ok")
    t:expect(r.client:get("artifacts", "build.log")):equals("ok")
    t:expect(r.client:list("artifacts")):equals({ "build.log" })
  end)
end)
