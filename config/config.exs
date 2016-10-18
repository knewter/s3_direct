# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :s3_direct,
  ecto_repos: [S3Direct.Repo]

# Configures the endpoint
config :s3_direct, S3Direct.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "rH+fVxJPrlepnLKWTLB3z6NU6R1/LWE4uyUQsocyrZAAm32127IDcHwb6ibmODEs",
  render_errors: [view: S3Direct.ErrorView, accepts: ~w(html json)],
  pubsub: [name: S3Direct.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :s3_direct, :aws,
  access_key_id: System.get_env("AWS_ACCESS_KEY_ID"),
  secret_key: System.get_env("AWS_SECRET_ACCESS_KEY"),
  bucket_name: "s3directupload-elixirsips"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
