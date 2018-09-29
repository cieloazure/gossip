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
    sum = Enum.at(opts, 0)
    weight = 1
    fact = ""
    receipt_counter = 0
    counter = 0
    neighbours = MapSet.new([])
    {:ok, {neighbours, fact, receipt_counter, counter, sum, weight}}
  end

  @impl true
  def handle_cast({:add_new_neighbours, new_neighbours}, {neighbours, fact, receipt_counter, _counter, sum, weight}) do
    new_neighbours = if !is_map(new_neighbours), do: MapSet.new(new_neighbours), else: new_neighbours
    {:noreply, {MapSet.union(neighbours,new_neighbours), fact, receipt_counter, MapSet.size(MapSet.union(neighbours,new_neighbours)), sum, weight}}
  end

  @impl true
  def handle_info({:fact, fact}, {neighbours, _fact, receipt_counter, counter, sum, weight}) do
    receipt_counter = receipt_counter + 1
    if receipt_counter == @counter_limit do
      IO.puts "#{sum} sending status"
      send_status(neighbours)
    end

    # if receipt_counter == 1, do: Process.spawn(fn -> send(Enum.random(neighbours), {:fact, fact}) end, [:monitor])

    if receipt_counter == 1  do
      Process.spawn(fn -> send(Enum.random(neighbours), {:fact, fact}) end, [:monitor])
    end
    {:noreply, {neighbours, fact, receipt_counter, counter, sum, weight}}
  end

  @impl true
  def handle_info({:pushsum}, {neighbours, fact, receipt_counter, counter, sum, weight}) do
    IO.puts "#{counter} sum estimate= #{sum/weight}"
    send(Enum.random(neighbours), {:pushsum, {sum/2, weight/2}})
    {:noreply, {neighbours, fact, receipt_counter, counter, sum/2, weight/2}}
  end

  @impl true
  def handle_info({:pushsum, {s, w}}, {neighbours, fact, receipt_counter, counter, sum, weight}) do
    IO.puts "puts with params------------------------"
    new_sum = sum + s
    new_weight = weight + w
    sum_estimate_delta = new_sum/new_weight - sum/weight
    
    receipt_counter = if sum_estimate_delta <= :math.pow(10, -10) do
      receipt_counter + 1
    else
      receipt_counter
    end
    
    {new_sum, new_weight} = if receipt_counter < 3 do
      send(Enum.random(neighbours), {:pushsum, {new_sum/2, new_weight/2}})
      {new_sum/2, new_weight/2}
    else
      {new_sum, new_weight}
    end

    IO.puts "#{counter} new sum estimate= #{new_sum/new_weight}"
    {:noreply, {neighbours, fact, receipt_counter, counter, new_sum, new_weight}}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _object, _reason}, {neighbours, fact, receipt_counter, counter, sum, weight}) do
    if counter != 0 do
      IO.puts "#{sum} down spawing"

      Process.spawn(fn -> send(Enum.random(neighbours), {:fact, fact}) end, [:monitor])
    end
    {:noreply, {neighbours, fact, receipt_counter, counter, sum, weight}}
  end

  @impl true
  def handle_call({:get_neighbours}, _from, {neighbours, _fact, _receipt_counter, _counter, _s, _w}) do
    {:reply, neighbours, {neighbours, _fact, _receipt_counter, _counter, _s, _w}}
  end

  @impl true
  def handle_info({:status, _status}, {_neighbours, _fact, receipt_counter, counter, sum, weight}) do
    counter = counter - 1
    IO.puts "#{sum} status #{counter}"
    # if counter == 0, do: receipt_counter = 11

    {:noreply, {_neighbours, _fact, receipt_counter, counter, sum, weight}}
  end

  # Private Functions
  defp send_status(neighbours) do
    Enum.map(neighbours, fn neighbour -> send(neighbour, {:status, @status}) end)
  end
end