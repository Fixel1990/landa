defmodule FlightTracker.FlightClient do
  @moduledoc """
  Client for interacting with the Aviationstack API.
  Handles flight data retrieval and API communication.
  """

  require Logger

  @base_url "http://api.aviationstack.com/v1"

  @doc """
  Get flight information by flight number.
  """
  def get_flight(flight_number) do
    api_key = get_api_key()

    if is_nil(api_key) or api_key == "" do
      Logger.error("Aviationstack API key not configured")
      {:error, "API key not configured"}
    else
      url = "#{@base_url}/flights"

      params = %{
        access_key: api_key,
        flight_iata: flight_number,
        limit: 1
      }

      Logger.debug("Making API request to #{url} with params: #{inspect(params)}")

      case Req.get(url, params: params) do
        {:ok, %{status: 200, body: body}} ->
          Logger.debug("API Response: #{inspect(body)}")
          handle_flight_response(body)
        {:ok, %{status: status, body: body}} ->
          Logger.error("Aviationstack API error: #{status} - #{inspect(body)}")
          {:error, "API error: #{status}"}
        {:error, reason} ->
          Logger.error("Failed to get flight data: #{inspect(reason)}")
          {:error, "Failed to get flight data"}
      end
    end
  end

  # Handle the API response and extract flight information
  defp handle_flight_response(%{"data" => [flight | _]}) do
    Logger.debug("Processing flight data: #{inspect(flight)}")

    # Extract flight information
    flight_info = %{
      flight_number: get_in(flight, ["flight", "iata"]) || get_in(flight, ["flight", "icao"]),
      airline: get_in(flight, ["airline", "name"]),
      aircraft: get_in(flight, ["aircraft", "registration"]),
      departure: extract_airport_info(flight["departure"]),
      arrival: extract_airport_info(flight["arrival"]),
      status: flight["flight_status"],
      scheduled_departure: parse_datetime(get_in(flight, ["departure", "scheduled"])),
      actual_departure: parse_datetime(get_in(flight, ["departure", "actual"])),
      scheduled_arrival: parse_datetime(get_in(flight, ["arrival", "scheduled"])),
      actual_arrival: parse_datetime(get_in(flight, ["arrival", "actual"])),
      estimated_arrival: parse_datetime(get_in(flight, ["arrival", "estimated"]))
    }

    Logger.debug("Extracted flight info: #{inspect(flight_info)}")
    {:ok, flight_info}
  end

  defp handle_flight_response(%{"data" => []}) do
    Logger.debug("No flight data found in API response")
    {:error, "Flight not found"}
  end

  defp handle_flight_response(response) do
    Logger.error("Unexpected API response format: #{inspect(response)}")
    {:error, "Unexpected response format"}
  end

  # Extract airport information
  defp extract_airport_info(nil), do: nil
  defp extract_airport_info(airport_data) do
    %{
      airport: airport_data["airport"],
      iata: airport_data["iata"],
      icao: airport_data["icao"],
      terminal: airport_data["terminal"],
      gate: airport_data["gate"]
    }
  end

  # Parse datetime strings
  defp parse_datetime(nil), do: nil
  defp parse_datetime(datetime_string) when is_binary(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _offset} -> datetime
      {:error, _reason} -> nil
    end
  end
  defp parse_datetime(_), do: nil

  # Get API key from configuration
  defp get_api_key do
    Application.get_env(:flight_tracker, :aviationstack_api_key) ||
      System.get_env("AVIATIONSTACK_API_KEY")
  end
end
