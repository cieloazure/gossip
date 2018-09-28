defmodule Gossip.Node do
  use GenServer

  @counter_limit 10

  @status "limit reached. Shutting Transmitting"

  # Client
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
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
  def init(opts) do
    s = Enum.at(opts, 0)
    w = 1
    fact = ""
    listen_counter = 0
    counter = 0
    neighbours = MapSet.new([])
    {:ok, {neighbours, fact, listen_counter, counter, s}}
  end

  @impl true
  def handle_cast({:add_new_neighbours, new_neighbours}, {neighbours, fact, listen_counter, _counter, s}) do
    new_neighbours = if !is_map(new_neighbours), do: MapSet.new(new_neighbours), else: new_neighbours
    {:noreply, {MapSet.union(neighbours,new_neighbours), fact, listen_counter, MapSet.size(MapSet.union(neighbours,new_neighbours)), s}}
  end

  @impl true
  def handle_info({:fact, fact}, {neighbours, _fact, listen_counter, counter, s}) do
    listen_counter = listen_counter + 1
    if listen_counter == @counter_limit do
      IO.puts "#{s} sending status"
      send_status(neighbours)
    end

    # if listen_counter == 1, do: Process.spawn(fn -> send(Enum.random(neighbours), {:fact, fact}) end, [:monitor])

    if listen_counter == 1  do
      Process.spawn(fn -> send(Enum.random(neighbours), {:fact, fact}) end, [:monitor])
    end
    {:noreply, {neighbours, fact, listen_counter, counter, s}}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _object, _reason}, {neighbours, fact, listen_counter, counter, s}) do
    if listen_counter <= @counter_limit or counter != 0 do
      IO.puts "#{s} down spawing"

      Process.spawn(fn -> send(Enum.random(neighbours), {:fact, fact}) end, [:monitor])
    end
    {:noreply, {neighbours, fact, listen_counter, counter, s}}
  end

  @impl true
  def handle_call({:get_neighbours}, _from, {neighbours, _fact, _listen_counter, _counter, _s}) do
    {:reply, neighbours, {_neighbours, _fact, listen_counter, counter, s}}
  end

  @impl true
  def handle_info({:status, _status}, {_neighbours, _fact, listen_counter, counter, s}) do
    counter = counter - 1
    IO.puts "#{s} status #{counter}"
    if counter == 0, do: listen_counter = 11

    {:noreply, {_neighbours, _fact, listen_counter, counter, s}}
  end

  # Private Functions
  defp send_status(neighbours) do
    Enum.map(neighbours, fn neighbour -> send(neighbour, {:status, @status}) end)
  end
end