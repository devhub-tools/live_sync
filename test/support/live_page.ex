defmodule LiveSync.LivePage do
  @moduledoc false
  use Phoenix.LiveView

  use LiveSync,
    watch: [
      :data,
      examples: [schema: LiveSync.Example]
    ]

  alias LiveSync.Repo

  def mount(_params, %{"id" => id} = session, socket) do
    send(session["test"], :ok)
    data = LiveSync.Example |> Repo.get!(id) |> Repo.preload([:parent, :children])
    {:ok, assign(socket, examples: [data], data: data, test: session["test"])}
  end

  def sync(:examples, updated, socket) do
    updates = Enum.sort_by(updated, & &1.name)
    send(self(), :synced)
    assign(socket, examples: updates)
  end

  def render(assigns) do
    ~H"""
    <div :if={not is_nil(@data)} id="data">
      <p id="data-id">{@data.id}</p>
      <p id="data-name">{@data.name}</p>
      <p id="data-enabled">{@data.enabled}</p>
      <p :if={not is_nil(@data.parent)} id="data-parent-name">{@data.parent.name}</p>
      <p :for={child <- @data.children} class="data-child-name">{child.name}</p>
    </div>
    <div id="examples">
      <div :for={example <- @examples}>
        <p class="example-id">{example.id}</p>
        <p class="example-name">{example.name}</p>
        <p class="example-enabled">{example.enabled}</p>
      </div>
    </div>
    """
  end

  # make sure not all handle_info are handled by LiveSync
  def handle_info(:synced, socket) do
    send(socket.assigns.test, :synced)
    {:noreply, socket}
  end
end
