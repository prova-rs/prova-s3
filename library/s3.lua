---@meta s3
--- LuaCATS annotations for the `s3` Prova plugin — the consumer-facing contract for
--- `local s3 = require("s3")`. prova syncs this into a project's `annotations/` so `require("s3")`
--- resolves by module name. Keep in step with `../s3.lua`.

---A docker-exec S3 client (drives `mc` against the MinIO container).
---@class s3.Client
local Client = {}

---@param name string bucket name
---@return s3.Client self
function Client:make_bucket(name) end

---@param bucket string
---@param key string
---@param content string
---@return s3.Client self
function Client:put(bucket, key, content) end

---@param bucket string
---@param key string
---@return string content
function Client:get(bucket, key) end

---@param bucket string
---@return string[] keys
function Client:list(bucket) end

---@param bucket string
---@param key string
---@return s3.Client self
function Client:remove(bucket, key) end

---No-op; the container teardown reaps everything.
function Client:close() end

---The provisioned S3 (MinIO): the trio plus the credentials the app under test needs to connect.
---@class s3.Resource
---@field client s3.Client the client to drive object storage
---@field url string the S3 endpoint for the app under test
---@field container prova.Container the raw container (host_port, logs, run, exec, stop)
---@field access_key string
---@field secret_key string

---@class s3
local s3 = {}

---Provision an ephemeral S3-compatible store (MinIO) and return the resource. Teardown is tied to `ctx`.
---@param ctx prova.Context
---@param opts { access_key?: string, secret_key?: string }?
---@return s3.Resource
function s3.container(ctx, opts) end

return s3
