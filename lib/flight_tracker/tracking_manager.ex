defmodule FlightTracker.TrackingManager do
  @moduledoc """
  GenServer that manages flight tracking state.
  Handles adding/removing flights from tracking and periodic status checks.
  Includes file-based persistence to survive restarts.
  """

  use GenServer
  alias FlightTracker.{FlightService, TelegramBotClient}
  require Logger

  @state_file "flight_tracking_state.bin"
  @check_interval 60_000  # Check every minute

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Track a flight for a specific chat.
  """
  def track_flight(chat_id, flight_number) do
    GenServer.call(__MODULE__, {:track_flight, chat_id, flight_number})
  end

  @doc """
  Stop tracking a flight for a specific chat.
  """
  def untrack_flight(chat_id, flight_number) do
    GenServer.call(__MODULE__, {:untrack_flight, chat_id, flight_number})
  end

  @doc """
  Get all tracked flights for a specific chat.
  """
  def get_tracked_flights(chat_id) do
    GenServer.call(__MODULE__, {:get_tracked_flights, chat_id})
  end

  @doc """
  Get all tracked flights across all chats.
  """
  def get_all_tracked_flights do
    GenServer.call(__MODULE__, :get_all_tracked_flights)
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    Logger.info("Starting TrackingManager...")

    # Load state from file
    state = load_state()
    Logger.info("Loaded tracking state: #{map_size(state)} chats with tracked flights")

    # Schedule periodic checks
    schedule_check()

    {:ok, state}
  end

  @impl true
  def handle_call({:track_flight, chat_id, flight_number}, _from, state) do
    # First check if the flight is trackable
    case FlightService.check_flight_trackable(flight_number) do
      {:ok, :trackable} ->
        # Add flight to tracking
        chat_flights = Map.get(state, chat_id, MapSet.new())
        updated_flights = MapSet.put(chat_flights, flight_number)
        new_state = Map.put(state, chat_id, updated_flights)

        # Save state
        save_state(new_state)

        Logger.info("Added flight #{flight_number} to tracking for chat #{chat_id}")
        {:reply, :ok, new_state}

      {:ok, :already_landed} ->
        Logger.info("Flight #{flight_number} has already landed, not tracking")
        {:reply, {:error, "🛬 Flight has already landed! No need to track it."}, state}

      {:ok, :cancelled} ->
        Logger.info("Flight #{flight_number} has been cancelled, not tracking")
        {:reply, {:error, "❌ Flight has been cancelled and cannot be tracked."}, state}

      {:error, reason} ->
        Logger.error("Failed to check flight trackability: #{reason}")
        {:reply, {:error, "❌ #{reason}"}, state}
    end
  end

  @impl true
  def handle_call({:untrack_flight, chat_id, flight_number}, _from, state) do
    chat_flights = Map.get(state, chat_id, MapSet.new())

    if MapSet.member?(chat_flights, flight_number) do
      updated_flights = MapSet.delete(chat_flights, flight_number)
      new_state = if MapSet.size(updated_flights) == 0 do
        Map.delete(state, chat_id)
      else
        Map.put(state, chat_id, updated_flights)
      end

      # Save state
      save_state(new_state)

      Logger.info("Removed flight #{flight_number} from tracking for chat #{chat_id}")
      {:reply, :ok, new_state}
    else
      {:reply, {:error, "Flight not being tracked"}, state}
    end
  end

  @impl true
  def handle_call({:get_tracked_flights, chat_id}, _from, state) do
    flights = Map.get(state, chat_id, MapSet.new()) |> MapSet.to_list()
    {:reply, flights, state}
  end

  @impl true
  def handle_call(:get_all_tracked_flights, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_info(:check_flights, state) do
    Logger.debug("Checking tracked flights...")
    new_state = check_all_flights(state)

    # Save state after checking flights
    save_state(new_state)

    # Schedule next check
    schedule_check()

    {:noreply, new_state}
  end

  @impl true
  def terminate(_reason, state) do
    Logger.info("TrackingManager terminating, saving state...")
    save_state(state)
    :ok
  end

  # Private functions

  defp schedule_check do
    Process.send_after(self(), :check_flights, @check_interval)
  end

  defp check_all_flights(state) do
    Enum.reduce(state, %{}, fn {chat_id, flights}, acc ->
      remaining_flights = check_chat_flights(chat_id, flights)

      if MapSet.size(remaining_flights) > 0 do
        Map.put(acc, chat_id, remaining_flights)
      else
        acc
      end
    end)
  end

  defp check_chat_flights(chat_id, flights) do
    Enum.reduce(flights, MapSet.new(), fn flight_number, acc ->
      if FlightService.flight_landed?(flight_number) do
        Logger.info("Flight #{flight_number} has landed! Notifying chat #{chat_id}")
        notify_flight_landed(chat_id, flight_number)
        acc  # Don't add to remaining flights
      else
        MapSet.put(acc, flight_number)  # Keep tracking
      end
    end)
  end

  defp notify_flight_landed(chat_id, flight_number) do
    case FlightService.get_flight_info(flight_number) do
      {:ok, flight_info} ->
        message = """
        🛬 <b>Flight Landed!</b>

        #{FlightService.format_flight_info(flight_info)}

        ✅ Flight #{flight_number} has arrived at its destination!
        """

        TelegramBotClient.send_message(chat_id, message)

      {:error, reason} ->
        message = "🛬 Flight #{flight_number} has landed! (Unable to get detailed info: #{reason})"
        TelegramBotClient.send_message(chat_id, message)
    end
  end

  # State persistence functions

  defp load_state do
    case File.read(@state_file) do
      {:ok, binary} ->
        try do
          state = :erlang.binary_to_term(binary)
          Logger.info("Successfully loaded state from #{@state_file}")
          state
        rescue
          error ->
            Logger.error("Failed to decode state file: #{inspect(error)}")
            Logger.info("Starting with empty state")
            %{}
        end

      {:error, :enoent} ->
        Logger.info("No state file found, starting with empty state")
        %{}

      {:error, reason} ->
        Logger.error("Failed to read state file: #{reason}")
        Logger.info("Starting with empty state")
        %{}
    end
  end

  defp save_state(state) do
    try do
      binary = :erlang.term_to_binary(state)
      case File.write(@state_file, binary) do
        :ok ->
          Logger.debug("State saved to #{@state_file}")
        {:error, reason} ->
          Logger.error("Failed to save state: #{reason}")
      end
    rescue
      error ->
        Logger.error("Failed to encode state: #{inspect(error)}")
    end
  end
end
