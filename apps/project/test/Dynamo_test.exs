
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
        measure_read_consistency(view,50,0)  
         
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

end



