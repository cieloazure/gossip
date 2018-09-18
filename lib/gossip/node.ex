defmodule Gossip.Node do
  use GenServer
  # Client
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def add_new_neighbours(pid, new_neighbours) do
    GenServer.cast(pid, {:add_new_neighbours, new_neighbours})
  end

  def add_new_neighbour(pid, new_neighbour) do
    new_neighbour = MapSet.new([new_neighbour])
    GenServer.cast(pid, {:add_new_neighbours, new_neighbour})
  end

  def get_neighbours(pid) do
    GenServer.call(pid, {:get_neighbours})
  end

  # Server (callbacks)

  @impl true
  def init(:ok) do
    neighbours = MapSet.new([])
    {:ok, neighbours}
  end

  @impl true
  def handle_cast({:add_new_neighbours, new_neighbours}, neighbours) do
    new_neighbours =
      if !is_map(new_neighbours), do: MapSet.new(new_neighbours), else: new_neighbours

    {:noreply, MapSet.union(neighbours, new_neighbours)}
  end

  @impl true
  def handle_info({:fact, _fact}, neighbours) do
    {:noreply, neighbours}
  end

  @impl true
  def handle_call({:get_neighbours}, _from, neighbours) do
    {:reply, neighbours, neighbours}
  end
end
