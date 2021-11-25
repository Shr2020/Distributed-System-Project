defmodule Dynamo do
  @moduledoc """
  An implementation of the Dynamo consensus protocol.
  """
  # Shouldn't need to spawn anything from this module, but if you do
  # you should add spawn to the imports.
  import Emulation, only: [send: 2, timer: 1, now: 0, whoami: 0]

  import Kernel,
    except: [spawn: 3, spawn: 1, spawn_link: 1, spawn_link: 3, send: 2]

  require Fuzzers
  # This allows you to use Elixir's loggers
  # for messages. See
  # https://timber.io/blog/the-ultimate-guide-to-logging-in-elixir/
  # if you are interested in this. Note we currently purge all logs
  # below Info
  require Logger

  # This structure contains all the process state
  # required by the Dynamo protocol.
  defstruct(
    # The list of current proceses.
    view: nil,
    # Current leader.
    store: nil,
    clock: %{},
    value_list: [],
    client_id: nil
  )

  @doc """
  Create state for an initial Dynamo cluster. Each
  process should get an appropriately updated versi
  of this state.
  """
 
  def new_configuration(
        view,
        store    
      ) do
    %Dynamo{
      view: view,
      store: Map.new()
    }
  end

  # Combine a single component in a vector clock.
  @spec combine_component(
          non_neg_integer(),
          non_neg_integer()
        ) :: non_neg_integer()
  defp combine_component(current, received) do
    if current > received do
      current 
    else 
      received
    end
  end

  @doc """
  Combine vector clocks: this is called whenever a
  message is received, and should return the clock
  from combining the two.
  """
  @spec combine_vector_clocks(map(), map()) :: map()
  def combine_vector_clocks(current, received) do
    # Map.merge just calls the function for any two components that
    # appear in both maps. Anything occuring in only one of the two
    # maps is just copied over. You should convince yourself that this
    # is the correct thing to do here.
    Map.merge(current, received, fn _k, c, r -> combine_component(c, r) end)
  end

  @doc """
  This function is called by the process `proc` whenever an
  event occurs, which for our purposes means whenever a message
  is received or sent.
  """
  
  def update_vector_clock(state) do
  me = whoami()
    clock = Map.update!(state.clock, me, fn existing_value -> existing_value + 1 end)
    %{state | clock: clock}
  end

  # Produce a new vector clock that is a copy of v1,
  # except for any keys (processes) that appear only
  # in v2, which we add with a 0 value. This function
  # is useful in making it so all process IDs do not
  # need to be known a-priori. YOU DO NOT NEED TO DIG
  # INTO THIS CODE, nor understand it.
  @spec make_vectors_equal_length(map(), map()) :: map()
  defp make_vectors_equal_length(v1, v2) do
    v1_add = for {k, _} <- v2, !Map.has_key?(v1, k), do: {k, 0}
    Map.merge(v1, Enum.into(v1_add, %{}))
  end

  # Compare two components of a vector clock c1 and c2.
  # Return @before if a vector of the form [c1] happens before [c2].
  # Return @after if a vector of the form [c2] happens before [c1].
  # Return @concurrent if neither of the above two are true.
  @spec compare_component(
          non_neg_integer(),
          non_neg_integer()
        ) :: :before | :after | :concurrent
  def compare_component(c1, c2) do
    cond do
      c1 < c2 -> :before
      c1 > c2 -> :after
      c1 = c2 -> :concurrent
    end
  end

  @doc """
  Compare two vector clocks v1 and v2.
  Returns @before if v1 happened before v2.
  Returns @hafter if v2 happened before v1.
  Returns @concurrent if neither of the above hold.
  """
  @spec compare_vectors(map(), map()) :: :before | :after | :concurrent
  def compare_vectors(v1, v2) do
    # First make the vectors equal length.
    v1 = make_vectors_equal_length(v1, v2)
    v2 = make_vectors_equal_length(v2, v1)
    # `compare_result` is a list of elements from
    # calling `compare_component` on each component of
    # `v1` and `v2`. Given this list you need to figure
    # out whether
    compare_result =
      Map.values(
        Map.merge(v1, v2, fn _k, c1, c2 -> compare_component(c1, c2) end)
      )
    a = Enum.all?(compare_result, fn x -> x == :before or x == :concurrent end)
    b = Enum.any?(compare_result, fn x -> x == :before end)
    c = Enum.all?(compare_result, fn x -> x == :after or x == :concurrent end)
    d = Enum.any?(compare_result, fn x -> x == :after end)
    e = Enum.all?(compare_result, fn x -> x == :concurrent end)
    cond do 
      a and b -> :before
      c and d -> :after
      b and d or e -> :concurrent
    end
  end

  # Insert the new value in store. First check for concurrency 
  def insert_in_store(state, key, value_pair) do
    existing_values = state.store.get(key)
    {value,current_vc} = value_pair
    state = %{state | clock: combine_vector_clocks(state.clock, current_vc)}
    concurrent_vals = Enum.filter(existing_values, fn {value,vc} -> if compare_vectors(vc, current_vc) == :concurrent do {value,vc}  end end)
    concurrent_vals = [value_pair] ++  concurrent_vals
    %{state | store: Map.put(state.store, key, concurrent_vals)}
  end
 
  def get_from_store(state, key) do
    # list of Values will be returned. [%Value{value: a, vc: [..]}, %Value{value: b, vc: [..]}]
     Map.get(state.store, key)
  end


 

  @doc """
  make_leader changes process state for a process that
  has just been elected leader.
  """
 
  
  def broadcast_to_others(state, message) do
    me = whoami()

    state.view
    |> Enum.filter(fn pid -> pid != me end)
    |> Enum.map(fn pid -> send(pid, message) end)
  end

  def become_replica(state) do
    me = whoami()
    new_clock = Map.put(state.clock,me,0)
       state = %{state | clock: new_clock}
    replica(state,%{version_num: 0,count: 0})
  end

def uniq(list) do
    uniq(list, MapSet.new)
  end

  defp uniq([x | rest], found) do
    {val,vc}=x
    if MapSet.member?(found, vc) do
      uniq(rest, found)
    else
      [x | uniq(rest, MapSet.put(found, vc))]
    end
  end

  defp uniq([], _) do
    []
  end

  def get_recent_value([head1|tail],l2,acc) do

      acc = loop1(head1,l2,acc)
      get_recent_value(tail,l2,acc)
end

def get_recent_value([],_,acc) do
  acc
end

def loop1(val1,[head2 | tail2],acc) do
{value1,vc1} = val1
{value2,vc2} = head2
if compare_vectors(vc1,vc2)!=:before do
  loop1(val1,tail2,acc)
else
  loop1([],[],acc)
end
end

def loop1(val1,[],acc) do
  acc+val1
end

def comparinglist(l1, l2 ) do
  uniq(get_recent_value(l1,l2,[]) ++ get_recent_value(l2,l1,[]))
  
end

  @doc """
  This function implements the state machine for a process
  that is currently the leader.

  `extra_state` can be used to hold any additional information.
  HINT: It might be useful to track the number of responses
  received for each AppendEntry request.
  """

  def replica(state,extra_state) do

    receive do
      {sender,{:get,key}} ->
        state = %{state | client_id: sender}
        state = %{state | current_key: key}
        state = %{state | value_list: [] ++ get_from_store(state,key)}
        broadcast_to_others(state,{:getfromreplicas,key})
        replica(state,extra_state)

      {sender,{:set,key,value}} ->
         state = %{state | client_id: sender}    
        state = insert_in_store(state,key,value)
        value_pair = {value,state.clock}
        insert_in_store(state, key, value_pair)
        broadcast_to_others(state,{:settoreplicas,key,value_pair})
        replica(state,extra_state)

      {sender,{:getfromreplicas,key}} ->
        value_pair = get_from_store(state,key)
        send(sender,{:replytoget,key,value_pair})
        replica(state,extra_state)

      {sender,{:settoreplicas,key,value_pair}} ->
        state = insert_in_store(state,key,value_pair)
        send(sender,{:replytoset,:ok,key})
        replica(state,extra_state)

      {sender,{:replytoget,key,value_pair}} ->
        len = floor(Enum.count(state.view) / 2)
        if key==state.current_key and extra_state.count<len do
          newvalue_pairs = comparinglist(state.value_list,value_pair)
          state = %{state | value_list: newvalue_pairs}
          extra_state = %{extra_state | count: extra_state.count+1}
           replica(state,extra_state)
        end
        if key==state.current_key and extra_state.count==len do
          newvalue_pairs = comparinglist(state.value_list,value_pair)
          state = %{state | value_list: newvalue_pairs}
          send(state.client_id,state.value_list)
           state = %{state | current_key: nil,value_list: nil,client_id: nil}
           extra_state = %{extra_state | count: 0}
           replica(state,extra_state)
        end
         replica(state,extra_state)
        
        {sender,{:replytoset,:ok,key}} ->
        len = floor(Enum.count(state.view) / 2)
        if key==state.current_key and extra_state.count<len do
          extra_state = %{extra_state | count: extra_state.count+1}
           replica(state,extra_state)
        end
        if key==state.current_key and extra_state.count==len do
           send(state.client_id,:ok)
           state = %{state | current_key: nil,client_id: nil}
           extra_state = %{extra_state | count: 0}
           replica(state,extra_state)
        end
         replica(state,extra_state)


     

    end
  end

  
end
defmodule Dynamo.Client do
  import Emulation, only: [send: 2]

  import Kernel,
    except: [spawn: 3, spawn: 1, spawn_link: 1, spawn_link: 3, send: 2]

  @moduledoc """
  A client that can be used to connect and send
  requests to the RSM.
  """
  alias __MODULE__
  @enforce_keys [:coordinator]
  defstruct(coordinator: nil)

  @doc """
  Construct a new Dynamo Client. This takes an ID of
  any process that is in the RSM. We rely on
  redirect messages to find the correct leader.
  """
  
  def new_client(member) do
    %Client{coordinator: member}
  end

  

  @doc """
  Send a dequeue request to the RSM.
  """
  
  def get(client,key) do
    coordinator = client.coordinator
    send(coordinator, {:get,key})

    receive do

      {_, v} ->
        {v, client}
    end
  end


  
  def put(client,key,value) do
    coordinator = client.coordinator
    send(coordinator, {:put,key,value})

    receive do
      {_, :ok} ->
        {:ok, client}
    end
  end
end
