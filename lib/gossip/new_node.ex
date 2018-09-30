defmodule Gossip.NewNode do
  use GenServer

  @susceptible "susceptible"
  @infected "infected"
  @removed "removed"
  @convergence_state_counter 10

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
    IO.inspect(new_neighbours)
    add_new_neighbours(pid, new_neighbours)
    # GenServer.cast(pid, {:add_new_neighbours, new_neighbours})
    Enum.each(new_neighbours, fn new_neighbour -> add_new_neighbour(new_neighbour, pid) end)
  end

  def get_neighbours(pid) do
    GenServer.call(pid, {:get_neighbours})
  end

  # Server
   
  @impl true
  def init(opts) do
    neighbours = MapSet.new([])
    fact = nil
    fact_counter = 0
    state = @susceptible
    fact_monger = spawn(Gossip.FactMonger, :run, [neighbours, -1, nil])
    {:ok, {neighbours, fact, fact_counter, state, fact_monger}}
  end


  @impl true
  def handle_cast({:add_new_neighbours, new_neighbours}, {neighbours, fact, fact_counter, state, fact_monger}) do
    new_neighbours = if !is_map(new_neighbours), do: MapSet.new(new_neighbours), else: new_neighbours
    send(fact_monger, {:neighbours, new_neighbours})
    {:noreply, {MapSet.union(neighbours,new_neighbours), fact, fact_counter, state, fact_monger}}
  end

  @impl true
  def handle_info({:fact, fact}, {neighbours, _fact, fact_counter, _state, fact_monger}) do
    # Received a fact
    # update the fact if hearing it for the first time
    # update the fact counter
    fact_counter = fact_counter + 1
    IO.inspect fact_counter
    state = cond do
      fact_counter == 1 -> 
        IO.puts "Changed state to infected just now #{inspect(self)}"
        send(fact_monger, {:fact, fact})
        @infected
      fact_counter > 1 and fact_counter < @convergence_state_counter ->
        IO.puts "Not yet reached convergence #{inspect(self)}"
        send(fact_monger, {:fact, fact})
        @infected
      fact_counter >= @convergence_state_counter -> 
        IO.puts "Reached convergence for #{inspect(self)}"
        if fact_counter == @convergence_state_counter do
          send(fact_monger, {:stop, 1})
        end
        @removed
      true -> 
        nil
    end

    {:noreply, {neighbours, fact, fact_counter, state, fact_monger}}
  end
end
