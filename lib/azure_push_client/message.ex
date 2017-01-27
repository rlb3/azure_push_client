defmodule AzurePushClient.Message do
  use GenServer
  alias AzurePushClient.Authorization, as: Auth
  require Logger

  def start_link do
    GenServer.start_link(__MODULE__, [], name: AzurePushClient)
  end

  @doc """
  # Usage

  AzurePushClient.Message.send({namespace, hub, access_key}, %{aps: %{alert: "Testing"}}, ["optional", "tag"], "apple")
  """

  def send({namespace, hub, access_key}, payload, tags \\ [], format \\ "apple") do
    GenServer.cast(AzurePushClient, {:send, payload, namespace, hub, access_key, tags, format})
  end

  def handle_cast({:send, payload, namespace, hub, access_key, tags, format}, state) do
    _send(payload, {namespace, hub, access_key}, tags, format)
    {:noreply, state}
  end

  defp _send(payload, {namespace, hub, access_key}, tags \\ [], format \\ "apple") do
    json_payload = Poison.encode!(payload)
    url = url(namespace, hub)
    content_type = "application/json"
    headers = [
      {"Content-Type", content_type},
      {"Authorization", Auth.token(url, access_key)},
      {"ServiceBusNotification-Format", format}
    ]
    headers = case Enum.join(tags, " || ") do
                "" -> headers
                tag_string -> [{"ServiceBusNotification-Tags", tag_string}|headers]
              end

    request(url, json_payload, headers)
  end

  defp url(namespace, hub) do
    "https://#{namespace}.servicebus.windows.net/#{hub}/messages"
  end

  defp request(url, payload, headers) do
    case HTTPoison.post(url, payload, headers, [ ssl: [{:versions, [:'tlsv1.2']}]]) do
      {:ok, %HTTPoison.Response{status_code: 201}} ->
        Logger.info "{:azure_push_client, :sent}"
        {:ok, :sent}
      {:ok, %HTTPoison.Response{status_code: 401}} ->
        Logger.error "{:azure_push_client, :unauthenticated}"
        {:error, :unauthenticated}
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error "{:azure_push_client, #{reason}}"
        {:error, reason}
    end
  end
end
