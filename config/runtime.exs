import Config

# Runtime configuration for production deployment
# This file is executed when the release starts

if config_env() == :prod do
  # Get environment variables with validation
  telegram_token =
    System.get_env("TELEGRAM_BOT_TOKEN") ||
    raise """
    Environment variable TELEGRAM_BOT_TOKEN is missing.
    Get a bot token from @BotFather on Telegram and set:
    export TELEGRAM_BOT_TOKEN="your_token_here"
    """

  aviationstack_api_key =
    System.get_env("AVIATIONSTACK_API_KEY") ||
    raise """
    Environment variable AVIATIONSTACK_API_KEY is missing.
    Get an API key from https://aviationstack.com/ and set:
    export AVIATIONSTACK_API_KEY="your_api_key_here"
    """

  config :flight_tracker,
    telegram_token: telegram_token,
    aviationstack_api_key: aviationstack_api_key

  # Production logger configuration
  config :logger,
    level: :info,
    backends: [:console]
end
