defmodule FlightTracker.TelegramBotPoller do
  @moduledoc """
  GenServer that polls for Telegram updates and processes them.
  Handles long polling with exponential backoff on errors.
  """

  use GenServer
  alias FlightTracker.{TelegramBotClient, TelegramBotHandler}
  require Logger

  @initial_backoff 1_000  # 1 second
  @max_backoff 60_000     # 1 minute
  @poll_timeout 30        # 30 seconds

  defstruct [:offset, :backoff]

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    Logger.info("Starting Telegram Bot Poller...")

    # Delete webhook to ensure we're using polling
    case TelegramBotClient.delete_webhook() do
      :ok ->
        Logger.info("Webhook deleted successfully, using polling mode")
      {:error, reason} ->
        Logger.warning("Failed to delete webhook: #{reason}")
    end

    # Get bot info to verify connection
    case TelegramBotClient.get_me() do
      {:ok, bot_info} ->
        Logger.info("Connected to Telegram bot: #{bot_info["first_name"]} (@#{bot_info["username"]})")
      {:error, reason} ->
        Logger.error("Failed to get bot info: #{reason}")
    end

    # Start polling immediately
    send(self(), :poll)

    {:ok, %__MODULE__{offset: 0, backoff: @initial_backoff}}
  end

  @impl true
  def handle_info(:poll, state) do
    case TelegramBotClient.get_updates(state.offset, @poll_timeout) do
      {:ok, updates} ->
        new_offset = process_updates(updates, state.offset)
        new_state = %{state | offset: new_offset, backoff: @initial_backoff}

        # Continue polling immediately on success
        send(self(), :poll)
        {:noreply, new_state}

      {:error, reason} ->
        Logger.error("Failed to get updates: #{reason}")

        # Exponential backoff on error
        new_backoff = min(state.backoff * 2, @max_backoff)
        Logger.info("Retrying in #{new_backoff}ms...")

        Process.send_after(self(), :poll, new_backoff)
        {:noreply, %{state | backoff: new_backoff}}
    end
  end

  @impl true
  def handle_info(msg, state) do
    Logger.warning("Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # Private functions

  defp process_updates([], offset), do: offset

  defp process_updates(updates, _offset) do
    Logger.debug("Processing #{length(updates)} updates")

    Enum.each(updates, fn update ->
      try do
        TelegramBotHandler.handle_update(update)
      rescue
        error ->
          Logger.error("Error processing update #{inspect(update)}: #{inspect(error)}")
      end
    end)

    # Return the next offset (last update_id + 1)
    case List.last(updates) do
      %{"update_id" => last_id} -> last_id + 1
      _ -> 0
    end
  end
end
