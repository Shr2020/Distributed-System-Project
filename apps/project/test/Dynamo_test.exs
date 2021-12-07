
defmodule DynamoTest do
  use ExUnit.Case
  import Emulation, only: [spawn: 2, send: 2]

  import Kernel,
    except: [spawn: 3, spawn: 1, spawn_link: 1, spawn_link: 3, send: 2]


  test "measure  reads after write probabilty" do
    Emulation.init()
    
    Emulation.append_fuzzers([Fuzzers.delay(50)])
    view = [:a, :b, :c]
    base_config =
      Dynamo.new_configuration(view, 1, 1, 20_000, 30_000)

    spawn(:b, fn -> Dynamo.become_replica(base_config) end)
    spawn(:c, fn -> Dynamo.become_replica(base_config) end)
    spawn(:a, fn -> Dynamo.become_replica(base_config) end)

    client =
      spawn(:client, fn ->
        client = Dynamo.Client.new_client(:client)
        measure_read_consistency(view,100,0)  
         
    end)

    handle = Process.monitor(client)
    # Timeout.
    receive do
      {:DOWN, ^handle, _, _, _} -> true
    after
      120_000 -> assert false
    end
  after
    Emulation.terminate()
  end

  def generate_random_val() do
    s = for _ <- 1..2, into: "", do: <<Enum.random('0123456789')>>
  end

  def measure_read_consistency(view,count,updated) do
    if count > 0 do
        random_server = Enum.random(view)
          IO.puts("selected randomserver #{inspect(random_server)}\n")
          val = generate_random_val()
          send(random_server,{:set,"p", val})
          Emulation.timer(200,:RL)
          read = measure_monotonic_reads(view,"p", val)
      measure_read_consistency(view,count-1,updated+read) 
    else
      IO.puts("probability#{inspect(updated/100)}\n")
      #values for fixed 100ms delay for R=1, W=1
      # after 200ms - 0.8 probability
      # after 500ms - 0.97 probability
      # after 800ms - 0.98 probability
      # after 1200ms - 1.0 probability
      # after 1500ms - 1.0 probability

      #values for fixed 100ms delay for R=1, W=2
      # after 200ms - 0.82 probability
      # after 500ms - 0.98 probability
      # after 800ms - 1.0 probability
      # after 1200ms - 1.0 probability
      # after 1500ms - 1.0 probability

      #values for fixed 100ms delay for R=2, W=1
      # after 200ms - 0.77 probability
      # after 500ms - 0.98 probability
      # after 800ms - 1.0 probability
      # after 1200ms - 1.0 probability
      # after 1500ms - 1.0 probability
    #------ R and w fixed to 1
      #values for fixed 100ms delay for N=3
      # after 200ms - 
      # after 500ms - 
      # after 800ms - 
      # after 1200ms - 
      # after 1500ms - 

      #values for fixed 100ms delay for N=4
      # after 200ms - 
      # after 500ms -
      # after 800ms - 
      # after 1200ms - 
      # after 1500ms - 

      #values for fixed 100ms delay for N=5
      # after 200ms - 
      # after 500ms - 
      # after 800ms - 
      # after 1200ms - 
      # after 1500ms -
    end
  end


  def measure_monotonic_reads(view, k, val) do
  receive do
    :RL -> 
      random_server = Enum.random(view)
      IO.puts("selected randomserver #{inspect(random_server)}\n")
      send(random_server,{:get,"p"})
      measure_monotonic_reads(view, k, val)
    {sender,{:get,^k,v}} ->
      if(Enum.member?(v,val)) do
        1
      else
        0
      end
   end
  end

  test "test k version staleness" do
    Emulation.init()
    
    Emulation.append_fuzzers([Fuzzers.delay(20)])
    view = [:a, :b, :c]
    base_config =
      Dynamo.new_configuration(view, 1, 1, 2_000, 3_000)

    spawn(:b, fn -> Dynamo.become_replica(base_config) end)
    spawn(:c, fn -> Dynamo.become_replica(base_config) end)
    spawn(:a, fn -> Dynamo.become_replica(base_config) end)
    # spawn(:d, fn -> Dynamo.become_replica(base_config) end)
    # spawn(:e, fn -> Dynamo.become_replica(base_config) end)
    # spawn(:f, fn -> Dynamo.become_replica(base_config) end)
    # spawn(:g, fn -> Dynamo.become_replica(base_config) end)

    client =
      spawn(:client, fn ->
        client = Dynamo.Client.new_client(:client)
       measure_k_staleness(view, client, 2) 
         
    end)

    handle = Process.monitor(client)
    # Timeout.
    receive do
      {:DOWN, ^handle, _, _, _} -> true
    after
      70_000 -> assert false
    end
  after
    Emulation.terminate()
  end


  def measure_k_staleness(view, client, k) do
    value_list = write_staleness_reads_probability(view, client, [], 100)
    for x <- 1..100 do
      random_server = Enum.random(view)
      IO.puts("selected randomserver #{inspect(random_server)}\n")
      send(random_server, {:get, "p"})
    end
    newlist = splitlist(value_list, k, [])
    staleness_reads_probability(view, "p", newlist, 0, 100)  
  end

def write_staleness_reads_probability(view, client, value_list, count) do
  if count > 0 do
    random_server = Enum.random(view)
    IO.puts("selected randomserver #{inspect(random_server)}\n")
    val = "pval#{count}"
    Dynamo.Client.set(client, random_server,"p", val)
    value_list = [val] ++ value_list
    IO.puts("list is  #{inspect(value_list)}\n")
    write_staleness_reads_probability(view, client, value_list, count-1)
  else
    value_list
   end
  end

  def staleness_reads_probability(view, k, val, updated, count) do
    receive do
      {sender,{:get, ^k, v}} ->
        IO.puts("list is  #{inspect(val)}\n")
        value_read = comparelist(val,v)
        if count > 1 do
          staleness_reads_probability(view, k, val, updated + value_read, count-1)
        else
          IO.puts("#{inspect(updated/100)}\n")
          # delay 20ms and N= 3 and R=1 AND W= 1
          #verifying on 100 writes and reads for different versions
          # 2 -> 0.73,0.69,0.57,0.84,0.73,0.65,0.48,0.64,0.87,0.63
          # 4 -> 0.96,0.78,0.96,0.8,0.99,0.99,0.99,0.89,0.91,0.99
          # 6 -> 0.99,0.99,0.999..
          # 8 -> 0.99

          # delay 10ms and N= 3 and R=2 AND W= 1
          #verifying on 100 writes and reads for different versions
          # 2 -> 0.86,0.66,0.77,0.7,0.81,0.86,0.66,0.7,0.69,0.68
          # 4 -> 0.99,0.99
          # 6 -> 0.99,0.99
          # 8 -> 0.99

          # delay 10ms and N= 3 and R=1 AND W= 2
          #verifying on 100 writes and reads for different versions
          # 2 -> 0.55,0.23,0.77,0.5,0.73,0.66,0.89,0.41,0.92,0.56
          # 4 -> 0.77,0.78,0.99,0.91,0.75,0.99,0.99
          # 6 -> 0.99,0.99
          # 8 -> 0.99

          #----conclusion:- write latency must be lower and read latency must be higher for more consistency---------

          # delay 20ms and N= 5 and R=1 AND W= 1
          #verifying on 100 writes and reads for different versions
          # 2 -> 0.68,0.29,0.48,0.38,0.7,0.58,0.42,0.67,0.46,0.71
          # 4 -> 0.84,0.76,0.43,0.66,0.51,0.91,0.83,0.61,0.76,0.6
          # 6 -> 0.89,0.73,0.99,0.56,0.68,0.87,0.66,0.77,0.83,0.61
          # 8 -> 0.99,0.76,0.86,0.91,0.61,0.89,0.76,0.59,0.78,0.91

            # delay 20ms and N= 7 and R=1 AND W= 1
          #verifying on 100 writes and reads for different versions
          # 2 -> 0.37,0.18,0.45,0.13,0.4,0.43,0.64,0.28,0.26,0.32
          # 4 -> 0.46,0.57,0.5,0.51,0.55,0.46,0.62,0.73,0.37,0.52
          # 6 -> 0.68,0.71,0.88,0.56,0.55,0.78,0.52,0.87,0.67,0.72
          # 8 -> 0.86,0.76,0.92,0.58,0.63,0.72,0.79,0.6,0.88,0.73
        end
    end
  end

  def comparelist([head1|tail1], l2) do
    if(Enum.member?(l2, head1)) do
      1
    else
      comparelist(tail1, l2)
    end
  end

  def comparelist([], l2) do
    0
  end

  def splitlist([head1|tail1], index, newlist) do
    if index > 0 do
      splitlist(tail1, index-1, [head1] ++ newlist)
    else
      newlist
    end
  end

  def comparelist([], l2) do
    []
  end
end



