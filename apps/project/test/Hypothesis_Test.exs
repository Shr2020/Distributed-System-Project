defmodule HypothesisTest do
  use ExUnit.Case
  import Emulation, only: [spawn: 2, send: 2]

  import Kernel,
    except: [spawn: 3, spawn: 1, spawn_link: 1, spawn_link: 3, send: 2]


  def generate_random_string() do
    s = for _ <- 1..3, into: "", do: <<Enum.random('abcdefghijklmnopqrstuvwxyz')>>
  end

  def generate_random_val() do
    s = for _ <- 1..2, into: "", do: <<Enum.random('0123456789')>>
  end

  test "merkle synchronization fails frequently on write intensive operations" do
    Emulation.init()
    Emulation.append_fuzzers([Fuzzers.delay(2)])
    view = [:a, :b, :c]
    base_config =
      Dynamo.new_configuration(view, 1, 2, 1_000, 2_000)

    spawn(:b, fn -> Dynamo.become_replica(base_config) end)
    spawn(:c, fn -> Dynamo.become_replica(base_config) end)
    spawn(:a, fn -> Dynamo.become_replica(base_config) end)

    client =
      spawn(:client, fn ->
        client = Dynamo.Client.new_client(:d)
        writes = 0
        while(writes < 10) do
            random_server = Enum.random(view)
            IO.puts(
            "selected randomserver #{inspect(random_server)}"
            )
            key = generate_random_string()
            val = generate_random_val()
            {v, client} = Dynamo.Client.set(client, random_server, key, val)
        end

        view |> Enum.map(fn x -> send(x, :send_merkle_attempts) end)
        success = %{a: 0, b: 0, c: 0}
        failure = %{a: 0, b: 0, c: 0}

        view
        |> Enum.map(fn x ->
            receive do
                {^x, s} -> 
                Map.put(success, x, s.success)
                Map.put(success, x, s.fail)
            end
        end)

        IO.puts("Success: #{inspect(success)}")
        IO.puts("Fail: #{inspect(fail)}")
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

  test "merkle synchronization fails on write intensive operations" do

  end


