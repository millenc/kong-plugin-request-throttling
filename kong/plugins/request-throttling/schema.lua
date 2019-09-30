return {
  name = "request-throttling",
  fields = {
    { config = {
        type = "record",
        fields = {
          { interval = { type = "number", required = true, gt = 0 }, },
          { burst_size = { type = "number", default = 1, gt = 0 }, },
          { burst_refresh = { type = "number", default = 1, gt = 0 }, },
          { max_wait_time = { type = "number", default = 60000, gt = -1 }, },
          { limit_by = { type = "string", one_of = {"consumer", "credential", "ip"}, default = "consumer" }, },
          { fault_tolerant = { type = "boolean", default = true }, },
          { redis_host = { type = "string", default = "localhost" }, },
          { redis_port = { type = "number", default = 6379 }, },
          { redis_password = { type = "string" }, },
          { redis_timeout = { type = "number", default = 2000 }, },
          { redis_database = { type = "number", default = 0 }, },
          { hide_client_headers = { type = "boolean", default = false }, },
        },
        custom_validator = function(config)
          -- basic validations TODO: extend?
          if config.burst_refresh > config.burst_size then
            return nil, "config.burst_refresh must be lower than or equal to config.burst_size"
          end
          if config.max_wait_time > 0 and config.interval >= config.max_wait_time then
            return nil, "config.interval must be lower than config.max_wait_time"
          end
          return true
        end
      },
    },
  },
}
