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

  def generate_random_num() do
    Enum.random(0..10)
  end

  test "merkle requests are rejected frequently on write intensive operations" do
    Emulation.init()
    Emulation.append_fuzzers([Fuzzers.delay(100)])
    view = [:a, :b, :c]
    base_config =
      Dynamo.new_configuration(view, 1, 2, 3_000, 4_000)

    spawn(:b, fn -> Dynamo.become_replica(base_config) end)
    spawn(:c, fn -> Dynamo.become_replica(base_config) end)
    spawn(:a, fn -> Dynamo.become_replica(base_config) end)

    client =
      spawn(:client, fn ->
        client = Dynamo.Client.new_client(:d)
        for x <- 1..10 do
            random_server = Enum.random(view)
            IO.puts(
            "selected randomserver #{inspect(random_server)}"
            )
            key = generate_random_string()
            val = generate_random_val()
            {v, client} = Dynamo.Client.set(client, random_server, key, val)
        end

        view |> Enum.map(fn x -> send(x, :send_merkle_attempts) end)

        stats =
          view
          |> Enum.map(fn x ->
              receive do
                  {^x, s} -> 
                  IO.puts("!!! #{x} ---> #{inspect(s)}")
              end
          end)
          IO.puts("**** STATS: #{inspect(stats)}")
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

  # test "merkle synchronization does not fail as frequently on write intensive operations" do
  #   Emulation.init()
  #   Emulation.append_fuzzers([Fuzzers.delay(500)])
  #   view = [:a, :b, :c]
  #   base_config =
  #     Dynamo.new_configuration(view, 1, 2, 1_000, 2_000)

  #   spawn(:b, fn -> Dynamo.become_replica(base_config) end)
  #   spawn(:c, fn -> Dynamo.become_replica(base_config) end)
  #   spawn(:a, fn -> Dynamo.become_replica(base_config) end)

  #   client =
  #     spawn(:client, fn ->
  #       client = Dynamo.Client.new_client(:d)
  #       {v, client} = Dynamo.Client.set(client, :a, "start", "start_val")
  #       keys = ["start"]
  #       keys = 
  #         for x <- 1..10 do
  #             IO.puts("!!!!!!!!!!!!!!!!!!!!!!!!!!!! #{x}  !!!!!!!!!!!!!!!!!!!!!")
  #             random_server = Enum.random(view)
  #             IO.puts("selected randomserver #{inspect(random_server)}")
  #             keys =
  #               if generate_random_num() < 4 do
  #                 key = generate_random_string()
  #                 val = generate_random_val()
  #                 {v, client} = Dynamo.Client.set(client, random_server, key, val)
  #                 key
  #               else
  #                  key = Enum.random(keys)
  #                  {value, c} = Dynamo.Client.get(client, random_server, key)
  #                  key
  #               end
  #         end

  #       view |> Enum.map(fn x -> send(x, :send_merkle_attempts) end)

  #       stats =
  #         view
  #         |> Enum.map(fn x ->
  #             receive do
  #                 {^x, s} -> 
  #                 IO.puts("!!! #{x} ---> #{inspect(s)}")
  #             end
  #         end)
  #         IO.puts("**** STATS: #{inspect(stats)}")
  #   end)

  #   handle = Process.monitor(client)
  #   # Timeout.
  #   receive do
  #     {:DOWN, ^handle, _, _, _} -> true
  #   after
  #     120_000 -> assert false
  #   end
  # after
  #   Emulation.terminate()
  # end
end


