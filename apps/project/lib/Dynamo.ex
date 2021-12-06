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
    
    store: %{},
    clock: %{},

    reqnum: 0,
    
    #merkle
    merkle_version: 0,
    merkle_hashchain: [],
    merkle_keys: [],
    
    #timers
    min_merkle_timeout: 0,
    max_merkle_timeout: 0,
    merkle_timer: nil,

    # gossip timer
    gossip_timeout: 4_000,
    gossip_timer: nil,
    roundTrip_timeout: 400,
    minProtocol_timeout: 800,
    pr: 0,
    sub_group_size: 2,
    roundTrip_timer: nil,
    minProtocol_timer: nil,
    ping_neighbour: nil,

    # Read_qourum
    r: 0,
    # write_qourum
    w: 0,

    # helpers for testing
    merkle_stat: %{success: 0, fail: 0}
  )

  @doc """
  Create state for an initial Dynamo cluster. Each
  process should get an appropriately updated versi
  of this state.
  """
  def new_configuration(view, r, w, min_merkle_tout, max_merkle_tout) do
    %Dynamo{
      view: view,
      
      r: r,
      w: w,
      min_merkle_timeout: min_merkle_tout,
      max_merkle_timeout: max_merkle_tout
    }
  end

  @spec get_merkle_time(%Dynamo{}) :: non_neg_integer()
  defp get_merkle_time(state) do
    state.min_merkle_timeout +
      :rand.uniform(
        state.max_merkle_timeout -
          state.min_merkle_timeout
      )
  end

  # Save a handle to the merkle timer.
  @spec save_merkle_timer(%Dynamo{}, reference()) :: %Dynamo{}
  defp save_merkle_timer(state, timer) do
    %{state | merkle_timer: timer}
  end

  # Save a handle to the gossip timer.
  @spec save_gossip_timer(%Dynamo{}, reference()) :: %Dynamo{}
  defp save_gossip_timer(state, timer) do
    %{state | gossip_timer: timer}
  end

  @spec reset_merkle_timer(%Dynamo{}) :: %Dynamo{}
  defp reset_merkle_timer(state) do
    if state.merkle_timer != nil do
      Emulation.cancel_timer(state.merkle_timer)
    end
    new_time = get_merkle_time(state)
    new_timer = Emulation.timer(new_time, :MT)
    state = save_merkle_timer(state, new_timer)
    state
  end

  @spec reset_gossip_timer(%Dynamo{}) :: %Dynamo{}
  defp reset_gossip_timer(state) do
    if state.gossip_timer != nil do
      Emulation.cancel_timer(state.gossip_timer)
    end
    new_timer = Emulation.timer(state.gossip_timeout, :GT)
    state = save_gossip_timer(state, new_timer)
    state
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
    state = 
    if state.store == %{} or Map.get(state.store,key)==nil do
      state = %{state | clock: combine_vector_clocks(state.clock, value_pair.vc)}
      state = %{state | store: Map.put(state.store, key, [value_pair])}
      state = Merkle.build_and_store_chain(state, state.store)
    else
      existing_values = Map.get(state.store,key)
      state = %{state | clock: combine_vector_clocks(state.clock, value_pair.vc)}
      concurrent_vals = Enum.filter(existing_values, fn x -> if compare_vectors(x.vc, value_pair.vc) == :concurrent do x  end end)
      concurrent_vals = uniq([value_pair] ++  concurrent_vals)
      state = %{state | store: Map.put(state.store, key, concurrent_vals)}
      state = Merkle.build_and_store_chain(state, state.store)
    end
  end
 
  def get_from_store(state, key) do
    # list of Values will be returned. [%Value{value: a, vc: [..]}, %Value{value: b, vc: [..]}]
     if(Map.get(state.store,key)==nil) do 
      []
     else
      Map.get(state.store, key)
    end
  end

  @doc """
  make_leader changes process state for a process that
  has just been elected leader.
  """  
  def broadcast_to_others(state, message) do
    me = whoami()

    state.view
    |> Enum.filter(fn pid -> pid != me end)
    |> Enum.map(fn pid -> 
    
    send(pid, message) end)
  end

  def become_replica(state) do
    me = whoami()
    state = reset_merkle_timer(state)
    new_clock = Map.put(state.clock,me,0)
       state = %{state | clock: new_clock}
    replica(state,%{},%{})
  end

  def uniq(list) do
      uniq(list, MapSet.new())
  end

  defp uniq([x | rest], found) do
    if MapSet.member?(found, x.vc) do
      uniq(rest, found)
    else
      [x | uniq(rest, MapSet.put(found, x.vc))]
    end
  end

  defp uniq([], _) do
    []
  end

  def get_recent_value([head1|tail], l2, acc) do
      acc = loop1(head1, l2, acc)
      get_recent_value(tail, l2, acc)
  end

  def get_recent_value([],l2, acc) do
    acc
  end


  def loop1(head1, [head2 | tail2],acc) do
    if compare_vectors(head1.vc, head2.vc) != :before do
      loop1(head1, tail2, acc)
    else
      acc
    end
  end

  def loop1(val1,[],acc) do
    acc ++ [val1]
  end

def comparinglist(l1, l2) do
  
  uniq(get_recent_value(l1, l2, []) ++ get_recent_value(l2, l1, []))
end

  @doc """
  """
  def replica(state,req_state,value_state) do

    receive do
      # get request from client
      {sender,{:get, key}} ->
       
        state = %{state | reqnum: state.reqnum+1}
        req_state = Map.put(req_state,state.reqnum,{0,sender})
        value_state = Map.put(value_state,state.reqnum,[])

        IO.puts("#{inspect(whoami())} received GET request for key: #{inspect(key)}\n")

        msg = ReplicationRequest.new(key, nil, state.reqnum,:get)
        broadcast_to_others(state, msg)
        msg = ReplicationResponse.new(key, get_from_store(state, key),state.reqnum, :get)
        send(whoami(), msg)
        replica(state, req_state,value_state)

      # set request from client
      {sender,{:set, key, value}} ->
        state = update_vector_clock(state)
        state = %{state | reqnum: state.reqnum+1}
        req_state = Map.put(req_state,state.reqnum,{0,sender})
        value_pair = Value.new(value, state.clock)

        IO.puts("#{inspect(whoami())} received SET request for key #{key} and value: #{inspect(value_pair)}\n")

        state = insert_in_store(state, key, value_pair)
        msg = ReplicationRequest.new(key, value_pair,state.reqnum, :set)
        broadcast_to_others(state,msg)
        msg = ReplicationResponse.new(key, value_pair,state.reqnum, :set)
        send(whoami(), msg)
        replica(state, req_state,value_state)

      # read qourum request
      {sender,
       %ReplicationRequest{
         key: key,
         value: value_pair,
         reqnum: reqnum,
         op: :get
       }} ->
        IO.puts("#{inspect(whoami())} received REPLICATION REQUEST request for key #{key} and value: #{inspect(value_pair)} and op: :GET\n")
        value_pair = get_from_store(state,key)

        msg = ReplicationResponse.new(key, value_pair, reqnum,:get)
        send(sender, msg)
        replica(state,req_state,value_state)

      # write qourum request
      {sender,
       %ReplicationRequest{
         key: key,
         value: value_pair,
         reqnum: reqnum,
         op: :set
       }} ->
       me = whoami()
        IO.puts("#{inspect(whoami())} received REPLICATION REQUEST request for key #{key} and value: #{inspect(value_pair)} and op: :SET\n")
        state = insert_in_store(state, key, value_pair)
        IO.puts("#{inspect(state.store)}\n")
        msg = ReplicationResponse.new(key,nil,reqnum,:set)
        send(sender, msg)
        replica(state, req_state,value_state)

      # read qourum replies
      {sender,
       %ReplicationResponse{
         key: key,
         value: value_pair,
         reqnum: index,
         op: :get
       }} ->
        
        IO.puts("#{inspect(whoami())} received REPLICATION RESPONSE request for key #{key} and value: #{inspect(value_pair)} and op: :GET\n")

        if Map.has_key?(req_state,index) do
          {count,client} = Map.get(req_state,index)
          req_state = Map.put(req_state,index,{count+1,client})
          if Map.get(req_state,index) < state.r do
            newvalue_pairs = comparinglist(Map.get(value_state,index), value_pair)
            value_state = Map.put(value_state,index,newvalue_pairs)
           replica(state,req_state,value_state)
          else
            newvalue_pairs = comparinglist(Map.get(value_state,index), value_pair)
            value_state = Map.put(value_state,index,newvalue_pairs)

            values = Enum.map(Map.get(value_state,index), fn x -> x.val end)
            {count,client} = Map.get(req_state,index)
            send(client, {:get,key,values})
            req_state = Map.delete(req_state,index)
            value_state = Map.delete(value_state,index)
           
            replica(state,req_state,value_state)
          end
        end
        replica(state,req_state,value_state)

      {sender,
       %ReplicationResponse{
         key: key,
         value: value,
         reqnum: index,
         op: :set
       }} ->
       me = whoami()
        IO.puts("#{inspect(whoami())} received REPLICATION RESPONSE request for key #{key} and value: #{inspect(value)} and op: :SET\n")
        if Map.has_key?(req_state,index) do
          {count,client} = Map.get(req_state,index)
          req_state = Map.put(req_state,index,{count+1,client})
          if Map.get(req_state,index) < state.w do
            req_state = Map.put(req_state,index,req_state.get(index)+1)
            replica(state,req_state,value_state)
          else
          {count,client} = Map.get(req_state,index)
          send(client,{:set,key,:ok})
          req_state = Map.delete(req_state,index)
          replica(state,req_state,value_state)
          end
        end
        replica(state,req_state,value_state)

      # Merkle Synchronization req
      {sender,
        %MerkleSynchroRequest{
          version: ver,
          merkle_chain: chain,
          match_entries: entries
      }} -> 
        # request sent first time
        IO.puts(
          "#{inspect(whoami)} received MERKLE REQUEST from #{inspect(sender)}. Contents: version=#{ver}  matched_entries=#{inspect(entries)}\n"
        )
        state = 
          if entries == [] do
            matched_hash = Merkle.compare_two_chains(state.merkle_hashchain, chain)
            state = 
              if List.starts_with?(matched_hash, chain) do
                send(sender, MerkleSynchroResponse.new(ver, matched_hash, True))
                state
              else
                send(sender, MerkleSynchroResponse.new(ver, matched_hash, False))
                state
              end
          else
            # request with entries
            state = Merkle.merge_and_resolve_kv(entries, state.store, state)
            state = Merkle.build_and_store_chain(state, state.store)
          end
        replica(state, req_state,value_state)
         
      # Merkle synchronization response
      {sender,
        %MerkleSynchroResponse{
          version: ver,
          matched_hashes: hash,
          success: succ
      }} -> 
        IO.puts(
          "#{inspect(whoami)} received MERKLE RESPONSE from #{inspect(sender)}. Contents: version=#{ver} success=#{inspect(succ)}\n"
        )
        # working on same merkle Tree
        state = 
          if ver == state.merkle_version do
            state = Map.put(state, :merkle_stat, Map.put(state.merkle_stat, :success, state.merkle_stat.success + 1))
            if succ == False do
              #synchronization needed
              entries = Merkle.get_unmatched_elements(state.store, hash, state.merkle_hashchain, state.merkle_keys)
              send(sender, MerkleSynchroRequest.new(state.merkle_version, state.merkle_hashchain, entries))
            end
            state
          else
            state = Map.put(state, :merkle_stat, Map.put(state.merkle_stat, :fail, state.merkle_stat.fail + 1))
            # version has changed. This response no longer valid. send request with new chain
            send(sender, MerkleSynchroRequest.new(state.merkle_version, state.merkle_hashchain, []))
            state
          end
        replica(state, req_state,value_state)

      # Merkle timeout. Send synchronization request
      :MT ->
        # if key value store has keys
        if Map.keys(state.store) != [] do
          # choose randomly one process
          sender = state.view |> Enum.filter(fn pid -> pid != whoami() end) |> Enum.random()
          # send request
          send(sender, MerkleSynchroRequest.new(state.merkle_version, state.merkle_hashchain, []))
        end
        state = reset_merkle_timer(state)
        replica(state, req_state,value_state) 

      :GT ->
        gt_timer= Emulation.timer(state.gossip_timeout,:GT)
        state = %{state | gossip_timer: gt_timer}
        state = Gossip.getRandomNeighbour(state)
        replica(state,req_state,value_state)

      :RT -> 
        k_list = Enum.take_random(state.view, state.sub_group_size)
        broadcast_to_others(k_list, {:pingreq,self(),state.ping_neighbour,state.pr})
        replica(state,req_state,value_state)

     {sender, {:ack,ping_neighbour,pr}} -> 
     if pr == state.pr do
      Emulation.cancel_timer(state.roundTrip_timer)
      Emulation.cancel_timer(state.minProtocol_timeout)
       broadcast_to_others(state.view,{ping_neighbour,:alive})
       if(!Enum.member?(state.view, ping_neighbour)) do
        state = %{state | view: [state.view | ping_neighbour]}
        replica(state,req_state,value_state)
      else
        replica(state,req_state,value_state)
        end
    else
        replica(state,req_state,value_state)
    end
      
      :MPT -> 
        broadcast_to_others(state.view,{state.ping_neighbour,:failed})
        if(Enum.member?(state.view, node)) do
          state = %{state | view: List.delete(state.view, node)}
          replica(state,req_state,value_state)
        else
          replica(state,req_state,value_state)
        end


      {sender,:joinreq} ->
        broadcast_to_others(state.view,{sender,:joined})
        send(sender,{:joinack,state.view})
        if(!Enum.member?(state.view, sender)) do
        state = %{state | view: state.view ++ [sender]}
        replica(state,req_state,value_state)
      else
        replica(state,req_state,value_state)
      end
      {sender,{node,:joined}} ->
        if(!Enum.member?(state.view, node)) do
        state = %{state | view: state.view ++ [node]}
        replica(state,req_state,value_state)
      else
        replica(state,req_state,value_state)
      end

      {sender,{:joinack,view}} ->
        state = %{state | view: uniq(state.view ++ view)}
        replica(state,req_state,value_state)


      {sender,{:ping,pr}} -> 
        send(sender,{:ack,pr})
        replica(state,req_state,value_state)

      {sender,{node,:alive}} ->
      if(!Enum.member?(state.view, node)) do
        state = %{state | view: state.view ++ [node]}
        replica(state,req_state,value_state)
      else
        replica(state,req_state,value_state)
      end

      {sender,{node,:failed}} ->
      if(Enum.member?(state.view, node)) do
        state = %{state | view: List.delete(state.view, node)}
        replica(state,req_state,value_state)
      else
        replica(state,req_state,value_state)
      end

      {sender, {:pingreq,pinger,ping_neighbour,pr}} ->
        send(ping_neighbour,{:indirectping,ping_neighbour,pinger,pr})
        replica(state,req_state,value_state)

      {sender, {:indirectping,ping_neighbour,pinger,pr}} ->
        send(sender,{:indirectack,ping_neighbour,pinger,pr})
        replica(state,req_state,value_state)

      
      {sender, {:indirectack,ping_neighbour,pinger,pr}} ->
        send(pinger,{:ack,pr})
        replica(state,req_state,value_state)


      # Msgs for testing
      {sender, "kill me"} ->
        IO.puts("Process: #{inspect(whoami)}  killed.\n")

      # to send merkle stat for hypothesis testing
      {sender, :send_merkle_attempts} ->
        send(sender, state.merkle_stat)
        replica(state, req_state,value_state)

      # send kv store for consistency check
      {sender, :send_kv} ->
        send(sender, state.store)
        replica(state, req_state,value_state)
      end
  end
end
