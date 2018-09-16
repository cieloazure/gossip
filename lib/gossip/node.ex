defmodule Gossip.Node do
  use GenServer
  # Client
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def add_new_neighbours(pid, new_neighbours) do
    GenServer.cast(pid, {:add_new_neighbours, new_neighbours})
  end

  # Server (callbacks)

  @impl true
  def init(:ok) do
    neighbours = MapSet.new([])
    {:ok, neighbours}
  end

  @impl true
  def handle_cast({:add_new_neighbours, new_neighbours}, neighbours) do
    IO.inspect new_neighbours
    new_neighbours = if !is_map(new_neighbours), do: MapSet.new(new_neighbours), else: new_neighbours
    {:noreply, MapSet.union(neighbours,new_neighbours)}
  end

  @impl true
  def handle_info({:fact, fact}, neighbours) do
    IO.inspect "Got a fact! Use logic to update the count of fact"
    {:noreply, neighbours}
  end
end
