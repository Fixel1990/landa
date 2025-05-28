# Flight Tracker Telegram Bot

A Telegram bot built with Elixir OTP that tracks flights and notifies users when they arrive at their destination.

## Features

- 🛩️ **Flight Tracking**: Track multiple flights simultaneously
- 🔔 **Real-time Notifications**: Get notified when flights land
- 📊 **Flight Information**: View detailed flight status and information
- 💾 **Persistent State**: Tracking survives bot restarts
- 🔄 **Automatic Cleanup**: Flights are automatically removed after landing
- 🛡️ **Pre-flight Validation**: Prevents tracking of already landed or cancelled flights

## Commands

- `/start` - Welcome message and bot introduction
- `/track <flight_number>` - Start tracking a flight (e.g., `/track KL1234`)
- `/untrack <flight_number>` - Stop tracking a specific flight
- `/list` - Show all currently tracked flights
- `/help` - Show help information

You can also send a flight number directly (like `KL1234`) to get current flight information.

## Architecture

The bot is built using Elixir OTP with the following components:

- **TelegramBotPoller**: Polls for Telegram updates using long polling
- **TelegramBotHandler**: Processes user commands and messages
- **TelegramBotClient**: HTTP client for Telegram Bot API
- **TrackingManager**: GenServer managing flight tracking state with persistence
- **FlightService**: High-level flight operations and business logic
- **FlightClient**: HTTP client for Aviationstack API

## Requirements

- Elixir 1.18+
- Telegram Bot Token (from @BotFather)
- Aviationstack API Key (from https://aviationstack.com/)

## Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd flight_tracker
```

2. Install dependencies:
```bash
mix deps.get
```

3. Set up environment variables:
```bash
export TELEGRAM_BOT_TOKEN="your_telegram_bot_token"
export AVIATIONSTACK_API_KEY="your_aviationstack_api_key"
```

## Development

Run the bot in development mode:

```bash
mix run --no-halt
```

Or start an interactive session:

```bash
iex -S mix
```

## Production Deployment

The project includes comprehensive deployment infrastructure for production:

### Using Mix Releases

1. Build a production release:
```bash
MIX_ENV=prod mix release
```

2. Run the release:
```bash
TELEGRAM_BOT_TOKEN="your_token" AVIATIONSTACK_API_KEY="your_key" _build/prod/rel/flight_tracker/bin/flight_tracker start
```

### Server Deployment

The project includes deployment scripts for server deployment:

- `deploy.sh` - Main deployment script
- `setup_server.sh` - Server preparation script
- `manage.sh` - Management script for the deployed service
- `flight-tracker.service` - Systemd service file

See `DEPLOYMENT.md` for detailed deployment instructions.

## Configuration

### Environment Variables

- `TELEGRAM_BOT_TOKEN` - Your Telegram bot token from @BotFather
- `AVIATIONSTACK_API_KEY` - Your Aviationstack API key

### Application Configuration

Configuration is handled through:
- `config/config.exs` - Base configuration
- `config/dev.exs` - Development environment
- `config/prod.exs` - Production environment  
- `config/runtime.exs` - Runtime configuration for releases

## State Persistence

The bot uses file-based persistence to survive restarts:

- **Format**: Erlang binary term format (`.bin` files)
- **Location**: `flight_tracking_state.bin` in the application root
- **Features**: Automatic state saving/loading, graceful error handling

## API Integration

### Aviationstack API

The bot integrates with the Aviationstack API for flight data:

- **Endpoint**: `http://api.aviationstack.com/v1/flights`
- **Features**: Real-time flight status, detailed flight information
- **Rate Limits**: Respects API rate limits and handles errors gracefully

## Monitoring and Logging

- **Structured Logging**: Comprehensive logging with different levels
- **Error Handling**: Graceful error handling with user-friendly messages
- **Health Checks**: Built-in health monitoring for all components

## Testing

Run the test suite:

```bash
mix test
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support or questions:
- Check the documentation in the `docs/` directory
- Review the deployment guides
- Check the logs for error messages

## Changelog

See `CHANGELOG.md` for version history and changes. 