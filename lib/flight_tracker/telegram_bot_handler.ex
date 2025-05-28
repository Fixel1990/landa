defmodule FlightTracker.TelegramBotHandler do
  @moduledoc """
  Handles incoming Telegram messages and commands.
  Processes user commands and coordinates with other services.
  """

  alias FlightTracker.{TelegramBotClient, TrackingManager, FlightService}
  require Logger

  @doc """
  Process an incoming Telegram update.
  """
  def handle_update(%{"message" => message}) do
    chat_id = get_in(message, ["chat", "id"])
    text = message["text"]

    if chat_id && text do
      Logger.info("Processing message from chat #{chat_id}: #{text}")
      handle_message(chat_id, text)
    else
      Logger.debug("Ignoring message without chat_id or text")
    end
  end

  def handle_update(update) do
    Logger.debug("Ignoring non-message update: #{inspect(update)}")
  end

  # Handle different message types
  defp handle_message(chat_id, "/start" <> _) do
    message = """
    🛩️ <b>Welcome to Flight Tracker Bot!</b>

    I can help you track flights and notify you when they arrive at their destination.

    <b>Available Commands:</b>
    /track &lt;flight_number&gt; - Start tracking a flight
    /untrack &lt;flight_number&gt; - Stop tracking a flight
    /list - Show your tracked flights
    /help - Show this help message

    <b>Example:</b>
    <code>/track KL1234</code>

    Just send me a flight number and I'll keep you updated! ✈️
    """

    TelegramBotClient.send_message(chat_id, message)
  end

  defp handle_message(chat_id, "/help" <> _) do
    message = """
    🛩️ <b>Flight Tracker Bot Help</b>

    <b>Commands:</b>

    🔍 <b>/track &lt;flight_number&gt;</b>
    Start tracking a flight. I'll notify you when it lands!
    Example: <code>/track KL1234</code>

    ❌ <b>/untrack &lt;flight_number&gt;</b>
    Stop tracking a specific flight.
    Example: <code>/untrack KL1234</code>

    📋 <b>/list</b>
    Show all flights you're currently tracking.

    ❓ <b>/help</b>
    Show this help message.

    <b>Tips:</b>
    • Use IATA flight codes (like KL1234, BA456)
    • I'll automatically stop tracking when flights land
    • You can track multiple flights at once

    Happy tracking! ✈️
    """

    TelegramBotClient.send_message(chat_id, message)
  end

  defp handle_message(chat_id, "/track " <> flight_number) do
    flight_number = String.trim(flight_number) |> String.upcase()

    if flight_number == "" do
      message = "❌ Please provide a flight number. Example: <code>/track KL1234</code>"
      TelegramBotClient.send_message(chat_id, message)
    else
      Logger.info("Tracking request for flight #{flight_number} from chat #{chat_id}")

      case TrackingManager.track_flight(chat_id, flight_number) do
        :ok ->
          # Get flight info to show current status
          case FlightService.get_flight_info(flight_number) do
            {:ok, flight_info} ->
              message = """
              ✅ <b>Now tracking flight #{flight_number}!</b>

              #{FlightService.format_flight_info(flight_info)}

              I'll notify you when this flight arrives! 🛬
              """
              TelegramBotClient.send_message(chat_id, message)

            {:error, _reason} ->
              message = "✅ Now tracking flight #{flight_number}! I'll notify you when it arrives. 🛬"
              TelegramBotClient.send_message(chat_id, message)
          end

        {:error, error_message} ->
          TelegramBotClient.send_message(chat_id, error_message)
      end
    end
  end

  defp handle_message(chat_id, "/untrack " <> flight_number) do
    flight_number = String.trim(flight_number) |> String.upcase()

    if flight_number == "" do
      message = "❌ Please provide a flight number. Example: <code>/untrack KL1234</code>"
      TelegramBotClient.send_message(chat_id, message)
    else
      Logger.info("Untrack request for flight #{flight_number} from chat #{chat_id}")

      case TrackingManager.untrack_flight(chat_id, flight_number) do
        :ok ->
          message = "✅ Stopped tracking flight #{flight_number}."
          TelegramBotClient.send_message(chat_id, message)

        {:error, "Flight not being tracked"} ->
          message = "❌ You're not currently tracking flight #{flight_number}."
          TelegramBotClient.send_message(chat_id, message)

        {:error, reason} ->
          message = "❌ Error: #{reason}"
          TelegramBotClient.send_message(chat_id, message)
      end
    end
  end

  defp handle_message(chat_id, "/list" <> _) do
    Logger.info("List request from chat #{chat_id}")

    case TrackingManager.get_tracked_flights(chat_id) do
      [] ->
        message = """
        📋 <b>Your Tracked Flights</b>

        You're not currently tracking any flights.

        Use <code>/track &lt;flight_number&gt;</code> to start tracking a flight!
        """
        TelegramBotClient.send_message(chat_id, message)

      flights ->
        flight_list = flights
        |> Enum.map(fn flight -> "✈️ #{flight}" end)
        |> Enum.join("\n")

        message = """
        📋 <b>Your Tracked Flights</b>

        #{flight_list}

        I'll notify you when any of these flights arrive! 🛬

        Use <code>/untrack &lt;flight_number&gt;</code> to stop tracking a specific flight.
        """
        TelegramBotClient.send_message(chat_id, message)
    end
  end

  # Handle flight number without command (direct flight lookup)
  defp handle_message(chat_id, text) when byte_size(text) <= 10 do
    # Check if it looks like a flight number (letters + numbers)
    if Regex.match?(~r/^[A-Z]{2}[0-9]{1,4}$/i, String.trim(text)) do
      flight_number = String.trim(text) |> String.upcase()
      Logger.info("Flight info request for #{flight_number} from chat #{chat_id}")

      case FlightService.get_flight_info(flight_number) do
        {:ok, flight_info} ->
          message = """
          #{FlightService.format_flight_info(flight_info)}

          💡 Want to track this flight? Use: <code>/track #{flight_number}</code>
          """
          TelegramBotClient.send_message(chat_id, message)

        {:error, "Flight not found"} ->
          message = "❌ Flight #{flight_number} not found. Please check the flight number and try again."
          TelegramBotClient.send_message(chat_id, message)

        {:error, reason} ->
          message = "❌ Error getting flight info: #{reason}"
          TelegramBotClient.send_message(chat_id, message)
      end
    else
      handle_unknown_command(chat_id, text)
    end
  end

  # Handle unknown commands
  defp handle_message(chat_id, text) do
    handle_unknown_command(chat_id, text)
  end

  defp handle_unknown_command(chat_id, text) do
    Logger.debug("Unknown command from chat #{chat_id}: #{text}")

    message = """
    ❓ I don't understand that command.

    <b>Available commands:</b>
    /track &lt;flight_number&gt; - Track a flight
    /untrack &lt;flight_number&gt; - Stop tracking a flight
    /list - Show tracked flights
    /help - Show help

    You can also send me a flight number directly (like KL1234) to get current flight info.
    """

    TelegramBotClient.send_message(chat_id, message)
  end
end
