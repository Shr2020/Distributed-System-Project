defmodule DynamoTest do
  use ExUnit.Case
  import Emulation, only: [spawn: 2, send: 2]

  import Kernel,
    except: [spawn: 3, spawn: 1, spawn_link: 1, spawn_link: 3, send: 2]

  test "checking dynamo" do
    Emulation.init()
    #Emulation.append_fuzzers([Fuzzers.delay(2)])
    view = [:a, :b, :c]
    base_config =
      Dynamo.new_configuration(view, 1, 2)

    spawn(:b, fn -> Dynamo.become_replica(base_config) end)
    spawn(:c, fn -> Dynamo.become_replica(base_config) end)
    spawn(:a, fn -> Dynamo.become_replica(base_config) end)

    client =
      spawn(:client, fn ->
        client = Dynamo.Client.new_client(:d)
        random_server = Enum.random(view)
        IO.puts(
          "selected randomserver #{inspect(random_server)}"
        )
        {v, client} = Dynamo.Client.set(client,random_server, :g, 5)
        IO.puts(
          "Received response for set #{inspect(v)} "
        )
        {value, client} = Dynamo.Client.get(client,random_server,:g)

        receive do
        after
          5_000 -> true
        end
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

end
