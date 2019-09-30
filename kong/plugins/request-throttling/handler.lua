-- Kong imports
local BasePlugin = require "kong.plugins.base_plugin"
local timestamp = require "kong.tools.timestamp"
local responses = kong.response
local redis = require "resty.redis"

local ngx_log = ngx.log
local fmt = string.format

local NULL_UUID = "00000000-0000-0000-0000-000000000000"
local THROTTLING_DELAY_HEADER = "X-Throttling-Delay"
local RETRY_AFTER_HEADER = "Retry-After"

local RequestThrottlingHandler = BasePlugin:extend()

RequestThrottlingHandler.PRIORITY = 901
RequestThrottlingHandler.VERSION = "0.3.0"

-- this is the script that gets executed by redis (atomically)
-- handles the token bucket and calculates the request release time in a single round trip
local REDIS_GET_NEXT_REQUEST_TIME_SCRIPT = [[
-- input parameters
local current_time = tonumber(ARGV[1])
local interval = tonumber(ARGV[2])
local max_wait_time = tonumber(ARGV[3])
local burst_size = tonumber(ARGV[4])
local burst_refresh = tonumber(ARGV[5])

-- local variables with default values
local next_time = current_time -- time when the request can be released. by default, we assume it is inmediately
local available_burst = burst_size -- available burst. by default, the maximum
local available_burst_last_update_time = current_time -- time when the burst balance was calculated. by default, now

-- get the current values on cache
if redis.call("EXISTS", KEYS[1]) == 1 then
  local cache_values = {}

  for cache_value in string.gmatch(redis.call("GET", KEYS[1]), "[^:]+") do
    table.insert(cache_values, cache_value)
  end

  available_burst = tonumber(cache_values[1])
  available_burst_last_update_time = tonumber(cache_values[2])
end

-- calculate burst balance
if current_time >= available_burst_last_update_time then
  local ticks = math.floor((current_time - available_burst_last_update_time) / interval) --# of burst balance calculate rounds

  available_burst = math.min(available_burst + (ticks * burst_refresh), burst_size)
  available_burst_last_update_time = available_burst_last_update_time + (ticks * interval)
else -- this should not happen
  return current_time
end

if available_burst > 0 then -- if there's burst available, the request can be released inmediately
  next_time = current_time
else -- if there's no burst available, calculate the needed burst balance rounds needed to generate it and add it
  local needed_ticks = math.ceil((1 + math.abs(available_burst)) / burst_refresh)

  next_time = available_burst_last_update_time + (needed_ticks * interval)
end

-- if the request goes through, reduce available burst
if next_time - current_time <= max_wait_time then
  available_burst = available_burst - 1
end

-- update cache with current burst values
redis.call('SET', KEYS[1], string.format("%s:%s", available_burst, available_burst_last_update_time))

return next_time
]]

local function get_user_identifier(conf)
  local identifier

  -- Consumer is identified by ip address or authenticated_credential id
  if conf.limit_by == "consumer" then
    identifier = ngx.ctx.authenticated_consumer and ngx.ctx.authenticated_consumer.id
    if not identifier and ngx.ctx.authenticated_credential then -- Fallback on credential
      identifier = ngx.ctx.authenticated_credential.id
    end
  elseif conf.limit_by == "credential" then
    identifier = ngx.ctx.authenticated_credential and ngx.ctx.authenticated_credential.id
  end

  if not identifier then
    identifier = ngx.var.remote_addr
  end

  return identifier
end

local function get_endpoint_identifiers(conf)
  -- Returns the API id or the service and/or route IDs
  conf = conf or {}

  local api_id = conf.api_id

  if api_id and api_id ~= ngx.null then
    return nil, nil, api_id
  end

  api_id = NULL_UUID

  local route_id   = conf.route_id
  local service_id = conf.service_id

  if not route_id or route_id == ngx.null then
    route_id = NULL_UUID
  end

  if not service_id or service_id == ngx.null then
    service_id = NULL_UUID
  end

  return service_id, route_id, api_id
end

local function get_cache_key(conf)
  -- Get the cache key used on redis for this API|Service+Route/consumer combination
  local user_identifier = get_user_identifier(conf)
  local service_id, route_id, api_id = get_endpoint_identifiers(conf)
  local endpoint_identifier = ""

  -- generate the endpoint identifier (use API id if set)
  if api_id == NULL_UUID then
    endpoint_identifier = fmt("%s:%s", service_id, route_id)
  else
    endpoint_identifier = api_id
  end

  return fmt("requestthrottling:%s:%s", endpoint_identifier, user_identifier)
end

local function get_next_request_time(conf, current_time)
  local cache_key = get_cache_key(conf)

  local red = redis:new()
  red:set_timeout(conf.redis_timeout)
  local ok, err = red:connect(conf.redis_host, conf.redis_port)
  if not ok then
    kong.log.err("failed to connect to Redis: ", err)
    return nil, err
  end

  local times, err = red:get_reused_times()
  if err then
    kong.log.err("failed to get connect reused times: ", err)
    return nil, err
  end

  if times == 0 and conf.redis_password and conf.redis_password ~= "" then
    local ok, err = red:auth(conf.redis_password)
    if not ok then
      kong.log.err("failed to auth Redis: ", err)
      return nil, err
    end
  end

  if times ~= 0 or conf.redis_database then
    -- The connection pool is shared between multiple instances of this
    -- plugin, and instances of the response-ratelimiting plugin.
    -- Because there isn't a way for us to know which Redis database a given
    -- socket is connected to without a roundtrip, we force the retrieved
    -- socket to select the desired database.
    -- When the connection is fresh and the database is the default one, we
    -- can skip this roundtrip.

    local ok, err = red:select(conf.redis_database or 0)
    if not ok then
      kong.log.err("failed to change Redis database: ", err)
      return nil, err
    end
  end

  -- eval script on redis. This gets the value for next_time and also increments this value on the cache side atomically (on a single round-trip)
  local next_time, err = red:eval(REDIS_GET_NEXT_REQUEST_TIME_SCRIPT,
                                  1,
                                  cache_key,
                                  current_time,
                                  conf.interval,
                                  conf.max_wait_time,
                                  conf.burst_size,
                                  conf.burst_refresh)
  return next_time, err
end

function RequestThrottlingHandler:new()
  RequestThrottlingHandler.super.new(self, "request-throttling")
end

function RequestThrottlingHandler:access(conf)
  RequestThrottlingHandler.super.access(self)

  local current_time = math.floor(timestamp.get_utc_ms())

  -- Get the time when the next request can be released
  local next_time, err = get_next_request_time(conf, current_time)
  if err then
    if conf.fault_tolerant then
      kong.log.err("failed to get next request time: ", tostring(err))
      return
    else
      return kong.response.exit(500, "Internal Server Error")
    end
  end

  -- Calculate sleep time (time needed to meet the desired rate)
  -- If the request has to wait for a long time (longer than max_wait_time), the request is dropped
  local sleep_time = (next_time - current_time) / 1000 --seconds
  if sleep_time > 0 then
    if sleep_time > conf.max_wait_time / 1000 then
      if conf.max_wait_time == 0 then
        ngx.header[RETRY_AFTER_HEADER] = sleep_time
      end

      return kong.response.exit(429, "API rate limit exceeded")
    else
      if not conf.hide_client_headers then
        ngx.header[THROTTLING_DELAY_HEADER] = sleep_time
      end

      ngx.sleep(sleep_time) -- put the request to sleep (apply delay)
    end
  end
end

return RequestThrottlingHandler
