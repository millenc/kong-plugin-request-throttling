Kong - Request Throttling Plugin
==============================

A [Kong](https://github.com/Kong/kong) plugin to do request throttling using the [Leaky Bucket](https://en.wikipedia.org/wiki/Leaky_bucket) algorithm. This plugin's goal is to send requests to the upstream at a fixed rate (defined by the user), thus avoiding request bursts from compromising the service.

As of now, this plugin is a proof of concept and not ready for production. Use it at your own discretion :).

[Requirements](#requirements) |
[Installation](#installation) |
[Configuration](#configuration) |
[Author](#author) |
[Contributing](#contributing) |
[Acknowledgements](#acknowledgements) |
[License](#license)

## Requirements

* [Kong](https://konghq.com/) (0.12.x or lower)
* [Redis](https://redis.io/) (4.0 or higher)

## Installation

Please see the [official documentation](https://docs.konghq.com/0.12.x/plugin-development/distribution/#installing-the-plugin) on how to install a plugin manually. Luarocks support comming soon!

## Configuration

Here's a list of all the parameters which can be used in this plugin's configuration:

| Form Parameter          | Default       | Description                                                                                                                                                               |
| -------------           | ------------- | -------------------                                                                                                                                                       |
| `name`                  |               | The name of the plugin to use, in this case `request-throttling`                                                                                                          |
| `consumer_id`           |               | The id of the Consumer which this plugin will target.                                                                                                                     |
| `config.interval`       |               | The interval between requests (ms). This parameter determines the rate at which requests will be sent to the upstream (one request every `config.interval` ms). Required. |
| `config.limit_by`       | `consumer`    | Limit requests by `consumer`, `credential` or `ip`.                                                                                                                       |
| `config.fault_tolerant` | `true`        | Do not fail if there's an error                                                                                                                                           |
| `config.max_wait_time`  | `60000`       | The maximum time (ms) a request will wait to be served. This, together with the `config.interval`, determines the size of the bucket.                                     |
| `config.redis_host`     | `localhost`   | Address of the Redis server used to keep track of request times.                                                                                                          |
| `config.redis_port`     | `6379`        | Port used by Redis.                                                                                                                                                       |
| `config.redis_password` |               | Password to use when the Redis server requires authentication (optional)                                                                                                  |
| `config.redis_timeout`  | `2000`        | Redis connection timeout (ms)                                                                                                                                             |
| `config.redis_database` | `0`           | Redis database                                                                                                                                                            |

## Author

* **Mikel Pintor** <millen@gmail.com>

## Contributing

All contributions are welcome! Please fork the repo, work on a named branch (with a descriptive name if possible) and create a pull request explaining the change or improvement you attempt to make.

## Acknowledgements

Thanks to [@aitormendivil](https://github.com/aitormendivil) and [@albertocr](https://github.com/albertocr) for their comments, insights and ideas!

## License

This project is under the [MIT license](https://github.com/millenc/kong-plugin-request-throttling/blob/master/LICENSE).
