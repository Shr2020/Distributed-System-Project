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

  # test "merkle requests are rejected frequently on write intensive operations" do
  #   Emulation.init()
  #   Emulation.append_fuzzers([Fuzzers.delay(100)])
  #   view = [:a, :b, :c]
  #   base_config =
  #     Dynamo.new_configuration(view, 1, 2, 1_000, 2_000)

  #   spawn(:b, fn -> Dynamo.become_replica(base_config) end)
  #   spawn(:c, fn -> Dynamo.become_replica(base_config) end)
  #   spawn(:a, fn -> Dynamo.become_replica(base_config) end)

  #   client =
  #     spawn(:client, fn ->
  #       client = Dynamo.Client.new_client(:d)
  #       for x <- 1..10 do
  #           random_server = Enum.random(view)
  #           IO.puts(
  #           "selected randomserver #{inspect(random_server)}"
  #           )
  #           key = generate_random_string()
  #           val = generate_random_val()
  #           {v, client} = Dynamo.Client.set(client, random_server, key, val)
  #       end

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

  # test "merkle synchronization does not fail as frequently on read intensive operations" do
  #   Emulation.init()
  #   Emulation.append_fuzzers([Fuzzers.delay(100)])
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

    test "measure time in obtaining consistency" do
    Emulation.init()
    start = System.monotonic_time()
    Emulation.append_fuzzers([Fuzzers.delay(200)])
    view = [:a, :b, :c, :d]
    base_config =
      Dynamo.new_configuration(view, 1, 1, 3_000, 4_000)

    spawn(:b, fn -> Dynamo.become_replica(base_config) end)
    spawn(:c, fn -> Dynamo.become_replica(base_config) end)
    spawn(:a, fn -> Dynamo.become_replica(base_config) end)
    spawn(:d, fn -> Dynamo.become_replica(base_config) end)

    client =
      spawn(:client, fn ->
        client = Dynamo.Client.new_client(:d)
        {v, client} = Dynamo.Client.set(client, :a, "start", "start_val")
        keys = ["start"]
        keys = 
          for x <- 1..5 do
              IO.puts("!!!!!!!!!!!!!!!!!!!!!!!!!!!! #{x}  !!!!!!!!!!!!!!!!!!!!!\n")
              random_server = Enum.random(view)
              IO.puts("selected randomserver #{inspect(random_server)}\n")
              keys =
                if generate_random_num() < 10 do
                  key = generate_random_string()
                  val = generate_random_val()
                  Dynamo.Client.set(client, random_server, key, val)
                  key
                else
                   key = Enum.random(keys)
                   Dynamo.Client.get(client, random_server, key)
                   key
                end
          end
        measure_time(view, start, true)
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

  def measure_time(view, time1, check_kv) do
    if check_kv == true do
      view |> Enum.map(fn x -> send(x, :send_kv) end)
        kv_list =
          view
          |> Enum.map(fn x ->
              receive do
                  {^x, s} -> s
              end
          end)
        if Helper.check_all_kv_consistent(kv_list, kv_list) == true do
          time2 = System.monotonic_time()
          diff = time2 - time1
          IO.puts("!!!!!!!! Time taken for synchronisation: #{inspect(diff)}\n")
          t1 = System.convert_time_unit(time1, :native, :millisecond)
          t2 = System.convert_time_unit(time2, :native, :millisecond)
          d = t2-t1
          IO.puts("!!!!!!!! Time taken for synchronisation in millisecons: #{inspect(d)}\n")
          measure_time(view, time1, false)
        else
          measure_time(view, time1, true)
        end
    end
  end


  test "measure staleness" do
    Emulation.init()
    
    Emulation.append_fuzzers([Fuzzers.delay(200)])
    view = [:a, :b, :c, :e]
    base_config =
      Dynamo.new_configuration(view, 1, 1, 3_000, 4_000)

    spawn(:b, fn -> Dynamo.become_replica(base_config) end)
    spawn(:c, fn -> Dynamo.become_replica(base_config) end)
    spawn(:a, fn -> Dynamo.become_replica(base_config) end)
    spawn(:e, fn -> Dynamo.become_replica(base_config) end)

    client =
      spawn(:client, fn ->
        client = Dynamo.Client.new_client(:d)
        Dynamo.Client.set(client, :a, "start", "start_val")
        keys = ["start"]
        keys = 
          for x <- 1..5 do
              IO.puts("!!!!!!!!!!!!!!!!!!!!!!!!!!!! #{x}  !!!!!!!!!!!!!!!!!!!!!\n")
              random_server = Enum.random(view)
              IO.puts("selected randomserver #{inspect(random_server)}\n")
              key =
                if generate_random_num() < 5 do
                  # insert new-valur pair
                  key = generate_random_string()
                  val = generate_random_val()
                  Dynamo.Client.set(client, random_server, key, val)
                  key
                else
                   #update some existing key 
                   key = Enum.random(keys)
                   val = generate_random_val()
                   Dynamo.Client.set(client, random_server, key, val)
                   key
                end
          end

        # send last write
        key = Enum.random(keys)
        val = "over"
        Dynamo.Client.set(client, :a, key, val)
        measure_staleness(client, view, key, val)
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

  def measure_staleness(client, view, key, val) do 

    view |> Enum.map(fn x -> Dynamo.Client.get(client, x, key) end)
      val_list =
        view
        |> Enum.map(fn x ->
            receive do
                {^x, {:get, key, val}} -> val
            end
        end)
      {stale, updated} = check_stale_vals(val_list, val, 0, 0)
      IO.puts("Num of times Stale data obtained: #{stale}" )
      IO.puts("Num of times Updated data obtained: #{updated}" )
    
  end

  def check_stale_vals([head|tail], val, stale, updated) do
    if head == val do
      updated = updated + 1
      check_stale_vals(tail, val, stale, updated)
    else
      stale = stale + 1
      check_stale_vals(tail, val, stale, updated)
    end
  end

  def check_stale_vals([], val, stale, updated) do
    {stale, updated}
  end
end



