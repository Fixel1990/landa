#!/bin/bash

# Flight Tracker Bot - Local Development Startup Script
# This script starts the bot locally for development and testing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if environment variables are set
check_env_vars() {
    local missing_vars=()
    
    if [[ -z "$TELEGRAM_BOT_TOKEN" ]]; then
        missing_vars+=("TELEGRAM_BOT_TOKEN")
    fi
    
    if [[ -z "$AVIATIONSTACK_API_KEY" ]]; then
        missing_vars+=("AVIATIONSTACK_API_KEY")
    fi
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required environment variables:"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        echo ""
        echo "Please set them before running the bot:"
        echo "  export TELEGRAM_BOT_TOKEN=\"your_telegram_bot_token\""
        echo "  export AVIATIONSTACK_API_KEY=\"your_aviationstack_api_key\""
        echo ""
        echo "Or create a .env file with:"
        echo "  TELEGRAM_BOT_TOKEN=your_telegram_bot_token"
        echo "  AVIATIONSTACK_API_KEY=your_aviationstack_api_key"
        exit 1
    fi
}

# Load environment variables from .env file if it exists
load_env_file() {
    if [[ -f ".env" ]]; then
        log_info "Loading environment variables from .env file..."
        set -a  # automatically export all variables
        source .env
        set +a
        log_success "Environment variables loaded from .env"
    fi
}

# Check if dependencies are installed
check_dependencies() {
    log_info "Checking dependencies..."
    
    if ! command -v mix &> /dev/null; then
        log_error "Elixir Mix is not installed. Please install Elixir first."
        exit 1
    fi
    
    if [[ ! -d "deps" ]]; then
        log_warning "Dependencies not found. Installing..."
        mix deps.get
    fi
    
    log_success "Dependencies are ready"
}

# Compile the application
compile_app() {
    log_info "Compiling application..."
    if mix compile; then
        log_success "Application compiled successfully"
    else
        log_error "Compilation failed"
        exit 1
    fi
}

# Clean up any existing state file for fresh start (optional)
clean_state() {
    if [[ "$1" == "--clean" ]]; then
        if [[ -f "flight_tracking_state.bin" ]]; then
            log_warning "Removing existing state file for fresh start..."
            rm flight_tracking_state.bin
            log_info "State file removed"
        fi
    fi
}

# Start the bot
start_bot() {
    log_info "Starting Flight Tracker Bot..."
    echo ""
    log_success "🛩️  Flight Tracker Bot is starting..."
    log_info "Bot will run in development mode with debug logging"
    log_info "Press Ctrl+C to stop the bot"
    echo ""
    
    # Start with Mix in development mode
    if [[ "$1" == "--iex" ]]; then
        log_info "Starting in interactive mode (IEx)..."
        iex -S mix
    else
        log_info "Starting in normal mode..."
        mix run --no-halt
    fi
}

# Show help
show_help() {
    cat << EOF
Flight Tracker Bot - Local Development Startup Script

Usage: $0 [options]

Options:
  --help, -h     Show this help message
  --clean        Remove existing state file before starting (fresh start)
  --iex          Start in interactive Elixir shell (IEx) mode
  --check-only   Only check environment and dependencies, don't start

Environment Variables Required:
  TELEGRAM_BOT_TOKEN      - Your Telegram bot token from @BotFather
  AVIATIONSTACK_API_KEY   - Your Aviationstack API key

Examples:
  $0                      # Start bot normally
  $0 --clean              # Start with fresh state
  $0 --iex                # Start in interactive mode
  $0 --check-only         # Just check if everything is ready

You can also create a .env file in the project root with your environment variables:
  TELEGRAM_BOT_TOKEN=your_token_here
  AVIATIONSTACK_API_KEY=your_api_key_here

EOF
}

# Main function
main() {
    echo "🛩️  Flight Tracker Bot - Development Startup"
    echo "=============================================="
    echo ""
    
    # Parse command line arguments
    case "${1:-}" in
        "--help"|"-h")
            show_help
            exit 0
            ;;
        "--check-only")
            load_env_file
            check_env_vars
            check_dependencies
            compile_app
            log_success "✅ All checks passed! Bot is ready to start."
            exit 0
            ;;
    esac
    
    # Load environment variables from .env if available
    load_env_file
    
    # Check environment variables
    check_env_vars
    
    # Check and install dependencies
    check_dependencies
    
    # Compile the application
    compile_app
    
    # Clean state if requested
    clean_state "$1"
    
    # Start the bot
    start_bot "$1"
}

export AVIATIONSTACK_API_KEY="1139a69a477c06412c799dfa171b56b5"
export TELEGRAM_BOT_TOKEN="7979504467:AAFnsz2vZw7DMWkfuYwgvKPX-DGk97SMshU"

# Handle Ctrl+C gracefully
trap 'echo -e "\n${YELLOW}[INFO]${NC} Shutting down bot..."; exit 0' INT

# Run main function with all arguments
main "$@" 