Kong - Request Throttling Plugin
==============================

A [Kong](https://github.com/Kong/kong) plugin to do request throttling using the [Token Bucket](https://en.wikipedia.org/wiki/Token_bucket) algorithm. The plugin's goal is to send requests to the upstream at a fixed rate (defined by the user), thus avoiding large request bursts from compromising the service. It does so by applying delays to requests on nginx side (sleep) before being dispatched to the upstream.

As of now, this plugin is a proof of concept and not ready for production. Use it at your own discretion :). Please note that this approach will certainly not work well when Kong has to manage a lot of concurrent users (this can lead to thousands of open connections) or when the delays applied are huge (clients or intermediate proxies may drop the connections before the requests are served).

[Requirements](#requirements) |
[Installation](#installation) |
[Configuration](#configuration) |
[Author](#author) |
[Contributing](#contributing) |
[Acknowledgements](#acknowledgements) |
[License](#license)

## Requirements

* [Kong](https://konghq.com/) (>=1.0): if you want to install this plugin on Kong >=0.12.x, please use the [0.1.0 version](https://github.com/millenc/kong-plugin-request-throttling/releases/tag/0.1.0).
* [Redis](https://redis.io/) (>=4.0)

## Installation

Please see the [official documentation](https://docs.konghq.com/1.3.x/plugin-development/distribution/) on how to install a plugin manually (Luarock not yet supported).

## Configuration

Here's a list of all the parameters which can be used to configure this plugin:

| Form Parameter               | Default       | Description                                                                                                                                         |
| -------------                | ------------- | -------------------                                                                                                                                 |
| `name`                       |               | The name of the plugin to use, in this case `request-throttling`                                                                                    |
| `consumer_id`                |               | The id of the Consumer which this plugin will target.                                                                                               |
| `config.interval`            |               | This parameter determines the rate (ms) at which tokens will be generated (`config.burst_refresh` tokens every `config.interval` ms). Required.     |
| `config.max_wait_time`       | `60000`       | The maximum time (ms) a request will wait to be served (applied delay).                                                                              |
| `config.burst_size`          | `1`           | The maximum number of requests per burst (token bucket capacity). If set to 1, only one request per `config.interval` will hit the upstream server. |
| `config.burst_refresh`       | `1`           | The number of tokens added to the bucket every `config.interval`.                                                                                   |
| `config.limit_by`            | `consumer`    | Limit requests by `consumer`, `credential` or `ip`.                                                                                                 |
| `config.fault_tolerant`      | `true`        | Do not fail if there's an error                                                                                                                     |
| `config.hide_client_headers` | `false`       | Do not return headers like `X-Throttling-Delay` to the user                                                                                         |
| `config.redis_host`          | `localhost`   | Address of the Redis server used to keep track of request times.                                                                                    |
| `config.redis_port`          | `6379`        | Port used by Redis.                                                                                                                                 |
| `config.redis_password`      |               | Password to use when the Redis server requires authentication (optional)                                                                            |
| `config.redis_timeout`       | `2000`        | Redis connection timeout (ms)                                                                                                                       |
| `config.redis_database`      | `0`           | Redis database                                                                                                                                      |

For example, suppose we have a service that can only handle 1 request every 5 seconds before overloading. We could configure this plugin with the following parameters:

* `config.interval = 5000`
* `config.burst_size = 1`
* `config.burst_refresh = 1`
* `config.max_wait_time = 10000`

With this configuration, we have a bucket of capacity `1` (`config.burst_size = 1`), where `1` new token is generated (`config.burst_refresh = 1`) every `5000` milliseconds (`config.interval = 5000`). This means that, if we send 4 requests at `t=0ms`, the plugin will:

* Send the first request inmediately to the upstream (no throttling applied). This consumes the only token available in the bucket.
* Make the second request wait for 5 seconds and send it to the upstream at `t=5000ms`. When the request arrives there are no tokens available (it's been consumed by the first request) and it must wait until a new one is generated (after `5000`ms).
* Make the third request wait for 10 seconds and send it to the upstream at `t=10000ms`. When the request arrives there are no tokens available. The only one available in the bucket was consumed by the first request and the next one is "reserved" by the second request (it will be generated and consumed at `t=5000ms`), so the request must wait until the next token is generated, after `10000`ms (`5000`ms to generate the token reserved by the second request and another `5000`ms to generate the one needed by this request).
* Drop the fourth request (with `429 - Too Many Requests` HTTP code), since its wait time (`15000`ms) would be higher than the allowed maximum (`config.max_wait_time = 10000`).

## Authors

* **Mikel Pintor** <https://github.com/millenc>
* **Alberto Cuesta** <https://github.com/albertocr>

## Contributing

All contributions are welcome! Please fork the repo, work on a named branch (with a descriptive name if possible) and create a pull request explaining the change or improvement you attempt to make.

## Acknowledgements

Thanks to [@aitormendivil](https://github.com/aitormendivil) and [@albertocr](https://github.com/albertocr) for their comments, insights and ideas!

## License

This project is under the [MIT license](https://github.com/millenc/kong-plugin-request-throttling/blob/master/LICENSE).
