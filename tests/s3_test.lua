-- Self-test for prova-minio: provision MinIO, then a put/get/list/remove round-trip through the
-- docker-exec mc client. Requires docker; skips otherwise.

local blob = prova.fixture("s3", Scope.File, function(ctx)
  return require("s3").container(ctx)
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
  end)

  g:test("url and credentials are exposed for the app under test", function(t)
    local r = t:use(blob)
    t:expect(r.url):matches("^http://")
    t:expect(r.access_key):equals("minioadmin")   -- an `extra` resource field beyond the trio
    t:expect(r.secret_key):equals("minioadmin")
  end)
end)
