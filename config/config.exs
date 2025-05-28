import Config

# General application configuration
config :flight_tracker,
  telegram_token: System.get_env("TELEGRAM_BOT_TOKEN"),
  aviationstack_api_key: System.get_env("AVIATIONSTACK_API_KEY")

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
