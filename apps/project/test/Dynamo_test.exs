defmodule DynamoTest do
  use ExUnit.Case
  import Emulation, only: [spawn: 2, send: 2]

  import Kernel,
    except: [spawn: 3, spawn: 1, spawn_link: 1, spawn_link: 3, send: 2]

  test "checking dynamo" do
    Emulation.init()
    Emulation.append_fuzzers([Fuzzers.delay(1_000)])
    view = [:a, :b, :c, :d, :e, :f]
    #delay_time = %{a: 0, b: 0, c: 0}
    base_config =
      Dynamo.new_configuration(view, 1, 1)

    spawn(:b, fn -> Dynamo.become_replica(base_config) end)
    spawn(:c, fn -> Dynamo.become_replica(base_config) end)
    spawn(:a, fn -> Dynamo.become_replica(base_config) end)
    spawn(:d, fn -> Dynamo.become_replica(base_config) end)
    spawn(:e, fn -> Dynamo.become_replica(base_config) end)
    spawn(:f, fn -> Dynamo.become_replica(base_config) end)

    client =
      spawn(:client, fn ->
        client = Dynamo.Client.new_client(:z)
        measure_read_write(client,view,100)
        
      end)

    handle = Process.monitor(client)
    # Timeout.
    receive do
      {:DOWN, ^handle, _, _, _} -> true
    after
      30_000 -> assert false
    end
  after
    Emulation.terminate()
  end

  def measure_read_write(client,view,count) do
    if count > 0 do
       random_server = Enum.random(view)
        IO.puts(
          "selected randomserver #{inspect(random_server)}"
        )
        {v, c} = Dynamo.Client.set(client,random_server, :p, count)
        IO.puts(
          "Received response for set #{inspect(v)} "
        )
      
        #send(random_server, {:set_delay, {:a,250}})
        random_server = Enum.random(view)
        {value, c} = Dynamo.Client.get(client,random_server,:p)
        IO.puts(
          "Received value for get server is #{inspect(random_server)} #{inspect(value)} "
        )
    measure_read_write(client,view,count-1)
    else
    count
    end
  end


end