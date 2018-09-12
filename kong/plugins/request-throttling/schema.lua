local Errors = require "kong.dao.errors"

return {
  fields = {
    interval = { type = "number", required = true },
    limit_by = { type = "string", enum = {"consumer", "credential", "ip"}, default = "consumer" },
    fault_tolerant = { type = "boolean", default = true },
    max_wait_time = { type = "number", default = 60000 },
    redis_host = { type = "string", default = "localhost" },
    redis_port = { type = "number", default = 6379 },
    redis_password = { type = "string" },
    redis_timeout = { type = "number", default = 2000 },
    redis_database = { type = "number", default = 0 },
    hide_client_headers = { type = "boolean", default = false }
  },
  self_check = function(schema, plugin_t, dao, is_update)
    -- basic validations TODO: extend?
    if plugin_t.max_wait_time < 1 then
      return false, Errors.schema "config.max_wait_time must be greather than 1"
    end
    if plugin_t.interval < 1 or plugin_t.interval >= plugin_t.max_wait_time then
      return false, Errors.schema "config.interval must be greather than 1 and lower than config.max_wait_time"
    end

    return true
  end
}
