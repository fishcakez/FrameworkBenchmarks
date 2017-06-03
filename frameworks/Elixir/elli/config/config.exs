use Mix.Config

config :hello, :api,
  port: 8080

config :hello, :sql,
  hostname: "localhost",
  username: "benchmarkdbuser",
  password: "benchmarkdbpass",
  database: "hello_world",
  pool_size: System.schedulers_online * 2

config :sasl, :sasl_error_logger, :false
