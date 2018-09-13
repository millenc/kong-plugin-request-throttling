Kong - Request Throttling Plugin
==============================

A [Kong](https://github.com/Kong/kong) plugin to do request throttling using the [Token Bucket](https://en.wikipedia.org/wiki/Token_bucket) algorithm. This plugin's goal is to send requests to the upstream at a fixed rate (defined by the user), thus avoiding large request bursts from compromising the service.

As of now, this plugin is a proof of concept and not ready for production. Use it at your own discretion :).

[Requirements](#requirements) |
[Installation](#installation) |
[Configuration](#configuration) |
[Author](#author) |
[Contributing](#contributing) |
[Acknowledgements](#acknowledgements) |
[License](#license)

## Requirements

* [Kong](https://konghq.com/) (0.12.x or higher)
* [Redis](https://redis.io/) (4.0 or higher)

## Installation

Please see the [official documentation](https://docs.konghq.com/0.14.x/plugin-development/distribution/) on how to install a plugin manually. Luarocks support comming soon!

## Configuration

Here's a list of all the parameters which can be used in this plugin's configuration:

| Form Parameter               | Default       | Description                                                                                                                                         |
| -------------                | ------------- | -------------------                                                                                                                                 |
| `name`                       |               | The name of the plugin to use, in this case `request-throttling`                                                                                    |
| `consumer_id`                |               | The id of the Consumer which this plugin will target.                                                                                               |
| `config.interval`            |               | This parameter determines the rate (ms) at which tokens will be generated (`config.burst_refresh` tokens every `config.interval` ms). Required.     |
| `config.max_wait_time`       | `60000`       | The maximum time (ms) a request will wait to be served.                                                                                             |
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

## Author

* **Mikel Pintor** <millen@gmail.com>

## Contributing

All contributions are welcome! Please fork the repo, work on a named branch (with a descriptive name if possible) and create a pull request explaining the change or improvement you attempt to make.

## Acknowledgements

Thanks to [@aitormendivil](https://github.com/aitormendivil) and [@albertocr](https://github.com/albertocr) for their comments, insights and ideas!

## License

This project is under the [MIT license](https://github.com/millenc/kong-plugin-request-throttling/blob/master/LICENSE).
