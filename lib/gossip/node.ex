defmodule Gossip.Node do
  @moduledoc """
  Depracated. Will be removed in future release
  """
  use GenServer

  @counter_limit 10
  @message_interval 2

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

  def add_new_neighbours_dual(pid, new_neighbours) do

    add_new_neighbours(pid, new_neighbours)
    # GenServer.cast(pid, {:add_new_neighbours, new_neighbours})
    Enum.each(new_neighbours, fn new_neighbour -> add_new_neighbour(new_neighbour, pid) end)
  end

  def get_neighbours(pid) do
    GenServer.call(pid, {:get_neighbours})
  end

  # Server (callbacks)

  @impl true
  def init(opts) do
    sum = Keyword.get(opts, :node_number)
    weight = 1
    fact = ""
    receipt_counter = 0
    counter = 0
    neighbours = MapSet.new([])
    {:ok, {neighbours, fact, receipt_counter, counter, sum, weight}}
  end

  @impl true
  @doc """
  Callback to handle messages of type '{:add_new_neighbours, new_neighbours}'

  Adds new_neighbours to the neighbours MapSet of the node.
  """
  def handle_cast({:add_new_neighbours, new_neighbours}, {neighbours, fact, receipt_counter, _counter, sum, weight}) do
    new_neighbours = if !is_map(new_neighbours), do: MapSet.new(new_neighbours), else: new_neighbours
    {:noreply, {MapSet.union(neighbours,new_neighbours), fact, receipt_counter, MapSet.size(MapSet.union(neighbours,new_neighbours)), sum, weight}}
  end

  @doc """
  Callback to handle messages of the type '{:fact, fact}'

  This Callback is responsible for receiving gossip messages and updating receipt_counter.
  Also initiates message transmission if receipt_counter == 1.
  """
  @impl true
  def handle_info({:fact, fact}, {neighbours, _fact, receipt_counter, counter, sum, weight}) do
    receipt_counter = receipt_counter + 1

    cond do
      receipt_counter == @counter_limit ->
        # IO.puts("#{sum} stopping")
        send_status(neighbours)
      receipt_counter == 1 ->
        Process.spawn(fn -> send(Enum.random(neighbours), {:fact, fact}) end, [:monitor])
      true -> nil
    end

    {:noreply, {neighbours, fact, receipt_counter, counter, sum, weight}}
  end

  @doc """
  Callback to handle messages of the type '{:pushsum}'

  This Callback accepts the initial message for pushsum from the Supervisor.
  """
  @impl true
  def handle_info({:pushsum}, {neighbours, fact, receipt_counter, counter, sum, weight}) do
    send(Enum.random(neighbours), {:pushsum, {sum/2, weight/2}})
    {:noreply, {neighbours, fact, receipt_counter, counter, sum/2, weight/2}}
  end

  @doc """
  Callback to handle messages of the type '{:pushum, sum, weight}'

  This callback accepts the pushsum messages, updates node's sum and weight, 
  and continues by transmitting pushsum message to a random neighbouring node.
  """
  @impl true
  def handle_info({:pushsum, {s, w}}, {neighbours, fact, receipt_counter, counter, sum, weight}) do
    new_sum = sum + s
    new_weight = weight + w
    sum_estimate_delta = new_sum/new_weight - sum/weight
    
    receipt_counter = if sum_estimate_delta <= :math.pow(10, -10) do
      receipt_counter + 1
    else
      receipt_counter
    end
    
    {new_sum, new_weight} = if receipt_counter < @counter_limit do
      send(Enum.random(neighbours), {:pushsum, {new_sum/2, new_weight/2}})
      {new_sum/2, new_weight/2}
    else
      {new_sum, new_weight}
    end

    {:noreply, {neighbours, fact, receipt_counter, counter, new_sum, new_weight}}
  end

  @doc """
  Callback to handle down message from monitored process.
  Starts a new process to send fact to another random neighbouring node.
  """
  @impl true
  def handle_info({:DOWN, _ref, :process, _object, _reason}, {neighbours, fact, receipt_counter, counter, sum, weight}) do
    if counter != 0 do

      Process.spawn(fn -> 
        Process.sleep(@message_interval)
        send(Enum.random(neighbours), {:fact, fact}) 
      end, [:monitor])
    end
    {:noreply, {neighbours, fact, receipt_counter, counter, sum, weight}}
  end

  @impl true
  def handle_info({:status, _status}, {neighbours, fact, receipt_counter, counter, sum, weight}) do
    counter = counter - 1
    {:noreply, {neighbours, fact, receipt_counter, counter, sum, weight}}
  end

  @impl true
  def handle_call({:get_neighbours}, _from, {neighbours, fact, receipt_counter, counter, sum, weight}) do
    {:reply, neighbours, {neighbours, fact, receipt_counter, counter, sum, weight}}
  end

  # Private Functions
  defp send_status(neighbours) do
    Enum.map(neighbours, fn neighbour -> send(neighbour, {:status, @status}) end)
  end
end
