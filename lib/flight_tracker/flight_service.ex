defmodule FlightTracker.FlightService do
  @moduledoc """
  Service for flight operations and tracking logic.
  Provides high-level functions for flight tracking and status checking.
  """

  alias FlightTracker.FlightClient
  require Logger

  @doc """
  Get flight information by flight number.
  """
  def get_flight_info(flight_number) do
    FlightClient.get_flight(flight_number)
  end

  @doc """
  Check if a flight is trackable (not already landed or cancelled).
  Returns:
  - {:ok, :trackable} if the flight can be tracked
  - {:ok, :already_landed} if the flight has already landed
  - {:ok, :cancelled} if the flight has been cancelled
  - {:error, reason} if there was an error checking the flight
  """
  def check_flight_trackable(flight_number) do
    case get_flight_info(flight_number) do
      {:ok, flight_info} ->
        Logger.debug("Checking trackability for flight #{flight_number}: status = #{flight_info.status}")

        case flight_info.status do
          status when status in ["landed", "arrived"] ->
            Logger.info("Flight #{flight_number} has already landed")
            {:ok, :already_landed}
          status when status in ["cancelled", "canceled"] ->
            Logger.info("Flight #{flight_number} has been cancelled")
            {:ok, :cancelled}
          _other_status ->
            Logger.info("Flight #{flight_number} is trackable (status: #{flight_info.status})")
            {:ok, :trackable}
        end

      {:error, reason} ->
        Logger.error("Failed to check flight trackability: #{reason}")
        {:error, reason}
    end
  end

  @doc """
  Check if a flight has landed.
  """
  def flight_landed?(flight_number) do
    case get_flight_info(flight_number) do
      {:ok, flight_info} ->
        status = flight_info.status
        Logger.debug("Flight #{flight_number} status: #{status}")

        # Check if flight has landed based on status
        landed = status in ["landed", "arrived"]

        # Also check if actual arrival time is set
        actual_arrival_set = not is_nil(flight_info.actual_arrival)

        result = landed or actual_arrival_set
        Logger.debug("Flight #{flight_number} landed check: status_landed=#{landed}, actual_arrival_set=#{actual_arrival_set}, result=#{result}")

        result

      {:error, reason} ->
        Logger.error("Failed to check if flight landed: #{reason}")
        false
    end
  end

  @doc """
  Format flight information for display.
  """
  def format_flight_info(flight_info) do
    departure_info = format_airport_info(flight_info.departure)
    arrival_info = format_airport_info(flight_info.arrival)

    status_emoji = case flight_info.status do
      "scheduled" -> "🕐"
      "active" -> "✈️"
      "landed" -> "🛬"
      "cancelled" -> "❌"
      "delayed" -> "⏰"
      _ -> "ℹ️"
    end

    """
    #{status_emoji} <b>#{flight_info.flight_number}</b> - #{flight_info.airline}

    📍 <b>From:</b> #{departure_info}
    📍 <b>To:</b> #{arrival_info}

    📊 <b>Status:</b> #{String.capitalize(flight_info.status || "unknown")}

    🕐 <b>Scheduled Departure:</b> #{format_datetime(flight_info.scheduled_departure)}
    🕐 <b>Scheduled Arrival:</b> #{format_datetime(flight_info.scheduled_arrival)}
    """ |> String.trim()
  end

  # Format airport information for display
  defp format_airport_info(nil), do: "Unknown"
  defp format_airport_info(airport) do
    airport_name = airport.airport || "Unknown Airport"
    iata_code = if airport.iata, do: " (#{airport.iata})", else: ""
    "#{airport_name}#{iata_code}"
  end

  # Format datetime for display
  defp format_datetime(nil), do: "Not available"
  defp format_datetime(%DateTime{} = datetime) do
    datetime
    |> DateTime.to_string()
    |> String.replace("T", " ")
    |> String.replace("Z", " UTC")
  end
  defp format_datetime(_), do: "Not available"
end
