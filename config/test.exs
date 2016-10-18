use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :s3_direct, S3Direct.Endpoint,
  http: [port: 4001],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :s3_direct, S3Direct.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "s3_direct_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox
