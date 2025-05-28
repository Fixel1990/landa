defmodule FlightTracker.Application do
  @moduledoc """
  The FlightTracker Application.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the tracking manager
      FlightTracker.TrackingManager,
      # Start the Telegram bot poller
      FlightTracker.TelegramBotPoller
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: FlightTracker.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
