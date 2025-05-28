import Config

# Production configuration
config :logger,
  level: :info,
  backends: [:console],
  compile_time_purge_matching: [
    [level_lower_than: :info]
  ]

# Ensure we don't accidentally start IEx in production
config :iex, default_prompt: ""

# Flight Tracker specific configuration
config :flight_tracker,
  # These will be set via runtime configuration from environment variables
  telegram_token: {:system, "TELEGRAM_BOT_TOKEN"},
  aviationstack_api_key: {:system, "AVIATIONSTACK_API_KEY"}

# Runtime configuration will be handled in config/runtime.exs
