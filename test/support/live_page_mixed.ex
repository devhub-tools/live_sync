defmodule LiveSync.LivePageMixed do
  @moduledoc false
  use Phoenix.LiveView

  use LiveSync,
    subscription_key: :organization_id,
    watch: [
      :data,
      examples: [schema: LiveSync.Example]
    ]

  alias LiveSync.Repo

  def mount(%{"id" => id}, session, socket) do
    data = LiveSync.Example |> Repo.get!(id) |> Repo.preload([:parent, :children, :ignored])
    {:ok, assign(socket, organization_id: 1, examples: [data], data: data, test: session["test"])}
  end

  def sync(:examples, updated, socket) do
    updates = Enum.sort_by(updated, & &1.name)
    send(self(), :synced_with_list)
    assign(socket, examples: updates)
  end

  def sync(:data, value, operation, socket) do
    data = Repo.preload(value, [:parent, :children])
    send(self(), {:synced_with_record, operation})
    assign(socket, data: data)
  end

  def render(assigns) do
    ~H"""
    <div :if={not is_nil(@data)} id="data">
      <p id="data-id">{@data.id}</p>
      <p id="data-name">{@data.name}</p>
    </div>
    <div id="examples">
      <div :for={example <- @examples}>
        <p class="example-id">{example.id}</p>
        <p class="example-name">{example.name}</p>
      </div>
    </div>
    """
  end

  # make sure not all handle_info are handled by LiveSync
  def handle_info(:synced_with_list, socket) do
    send(socket.assigns.test, :synced_with_list)
    {:noreply, socket}
  end

  def handle_info({:synced_with_record, operation}, socket) do
    send(socket.assigns.test, {:synced_with_record, operation})
    {:noreply, socket}
  end
end
