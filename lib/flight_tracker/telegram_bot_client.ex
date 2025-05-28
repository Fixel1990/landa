defmodule FlightTracker.TelegramBotClient do
  @moduledoc """
  Client for interacting with the Telegram Bot API.
  Handles sending messages and polling for updates.
  """

  require Logger

  @base_url "https://api.telegram.org/bot"

  @doc """
  Send a message to a Telegram chat.
  """
  def send_message(chat_id, text) do
    token = get_bot_token()

    if is_nil(token) or token == "" do
      Logger.error("Telegram bot token not configured")
      {:error, "Bot token not configured"}
    else
      url = "#{@base_url}#{token}/sendMessage"

      params = %{
        chat_id: chat_id,
        text: text,
        parse_mode: "HTML"
      }

      case Req.post(url, json: params) do
        {:ok, %{status: 200}} ->
          :ok
        {:ok, %{status: status, body: body}} ->
          Logger.error("Telegram API error: #{status} - #{inspect(body)}")
          {:error, "Telegram API error: #{status}"}
        {:error, reason} ->
          Logger.error("Failed to send message: #{inspect(reason)}")
          {:error, "Failed to send message"}
      end
    end
  end

  @doc """
  Get updates from Telegram Bot API using long polling.
  """
  def get_updates(offset \\ 0, timeout \\ 30) do
    token = get_bot_token()

    if is_nil(token) or token == "" do
      {:error, "Bot token not configured"}
    else
      url = "#{@base_url}#{token}/getUpdates"

      params = %{
        offset: offset,
        timeout: timeout
      }

      case Req.get(url, params: params, receive_timeout: (timeout + 5) * 1000) do
        {:ok, %{status: 200, body: %{"ok" => true, "result" => updates}}} ->
          {:ok, updates}
        {:ok, %{status: 200, body: %{"ok" => false, "description" => description}}} ->
          {:error, description}
        {:ok, %{status: status, body: body}} ->
          Logger.error("Telegram API error: #{status} - #{inspect(body)}")
          {:error, "Telegram API error: #{status}"}
        {:error, reason} ->
          Logger.error("Failed to get updates: #{inspect(reason)}")
          {:error, "Failed to get updates"}
      end
    end
  end

  @doc """
  Get bot information.
  """
  def get_me do
    token = get_bot_token()

    if is_nil(token) or token == "" do
      {:error, "Bot token not configured"}
    else
      url = "#{@base_url}#{token}/getMe"

      case Req.get(url) do
        {:ok, %{status: 200, body: %{"ok" => true, "result" => bot_info}}} ->
          {:ok, bot_info}
        {:ok, %{status: 200, body: %{"ok" => false, "description" => description}}} ->
          {:error, description}
        {:ok, %{status: status, body: body}} ->
          Logger.error("Telegram API error: #{status} - #{inspect(body)}")
          {:error, "Telegram API error: #{status}"}
        {:error, reason} ->
          Logger.error("Failed to get bot info: #{inspect(reason)}")
          {:error, "Failed to get bot info"}
      end
    end
  end

  @doc """
  Delete webhook (switch back to polling).
  """
  def delete_webhook do
    token = get_bot_token()

    if is_nil(token) or token == "" do
      {:error, "Bot token not configured"}
    else
      url = "#{@base_url}#{token}/deleteWebhook"

      case Req.post(url) do
        {:ok, %{status: 200, body: %{"ok" => true}}} ->
          :ok
        {:ok, %{status: 200, body: %{"ok" => false, "description" => description}}} ->
          {:error, description}
        {:ok, %{status: status, body: body}} ->
          Logger.error("Telegram API error: #{status} - #{inspect(body)}")
          {:error, "Telegram API error: #{status}"}
        {:error, reason} ->
          Logger.error("Failed to delete webhook: #{inspect(reason)}")
          {:error, "Failed to delete webhook"}
      end
    end
  end

  # Private helper to get bot token
  defp get_bot_token do
    Application.get_env(:flight_tracker, :telegram_token) ||
      System.get_env("TELEGRAM_BOT_TOKEN")
  end
end
