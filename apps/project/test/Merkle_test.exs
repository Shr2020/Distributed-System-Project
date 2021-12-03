defmodule MerkleTest do
  use ExUnit.Case
  doctest Merkle

  test "test merge_and_resolve_map" do
    state = %{}

    value_a_1 = Value.new(1, %{x: 1, y: 0, z: 0}) 
    value_a_2 = Value.new(2, %{x: 0, y: 0, z: 1}) 
    value_a_3 = Value.new(3, %{x: 1, y: 1, z: 0}) 
    value_a_4 = Value.new(4, %{x: 1, y: 0, z: 1}) 
    
    value_b_1 = Value.new(6, %{x: 1, y: 0, z: 0}) 
    value_b_2 = Value.new(7, %{x: 1, y: 1, z: 1})
    
    value_c_1 = Value.new(8, %{x: 1, y: 3, z: 1})
    
    value_d_1 = Value.new(9, %{x: 2, y: 1, z: 1})

    received = %{"a": [value_a_3, value_a_4], 
                 "b": [value_b_1], 
                 "d": [value_d_1]}

    kv = %{"a": [value_a_1, value_a_2], 
           "b": [value_b_2], 
           "c": [value_c_1]}

    state = Merkle.merge_and_resolve_kv(received, kv, state)
    expected_map =  %{a: [%Value{val: 3, vc: %{x: 1, y: 1, z: 0}}, %Value{val: 4, vc: %{x: 1, y: 0, z: 1}}], 
                      b: [%Value{val: 7, vc: %{x: 1, y: 1, z: 1}}], 
                      c: [%Value{val: 8, vc: %{x: 1, y: 3, z: 1}}], 
                      d: [%Value{val: 9, vc: %{x: 2, y: 1, z: 1}}]}
    assert state.store == expected_map
  end

  test "test get_unmatched_elements" do
    kv =  %{a: [%Value{val: 3, vc: %{x: 1, y: 1, z: 0}}, %Value{val: 4, vc: %{x: 1, y: 0, z: 1}}], 
                      b: [%Value{val: 7, vc: %{x: 1, y: 1, z: 1}}], 
                      c: [%Value{val: 8, vc: %{x: 1, y: 3, z: 1}}], 
                      d: [%Value{val: 9, vc: %{x: 2, y: 1, z: 1}}]}
    
    key_list = [:a, :b, :c, :d]

    merkle_chain = [4, 3, 2, 1]

    received = [2, 1]

    elements = Merkle.get_unmatched_elements(kv, received, merkle_chain, key_list)

    expected = %{a: [%Value{val: 3, vc: %{x: 1, y: 1, z: 0}}, %Value{val: 4, vc: %{x: 1, y: 0, z: 1}}], 
                 b: [%Value{val: 7, vc: %{x: 1, y: 1, z: 1}}]}

    assert elements == expected
  end

  test "compare_two_chains" do
    mA = [1, 2, 3, 4, 5, 6]
    mB = [0, 7, 8, 9, 5, 6 ]
    result = Merkle.compare_two_chains(mA, mB)
    expected = [5, 6]
    assert result == expected

    mA = [1, 2, 3, 4, 5, 6]
    mB = [7, 3, 4, 5, 6]
    result = Merkle.compare_two_chains(mA, mB)
    expected = [3, 4, 5, 6]
    assert result == expected

    mA = [1, 2, 3, 4, 5, 6]
    mB = [7, 8, 9, 5, 6]
    result = Merkle.compare_two_chains(mA, mB)
    expected = [5, 6]
    assert result == expected

    mA = [1, 3, 5, 6]
    mB = [7, 8, 9, 10, 5, 6]
    result = Merkle.compare_two_chains(mA, mB)
    expected = [5, 6]
    assert result == expected

    mA = [1, 3, 5, 6]
    mB = [7, 8, 9, 10, 5, 6]
    result = Merkle.compare_two_chains(mA, mB)
    expected = [5, 6]
    assert result == expected
  end

  test "build_and_store_chain" do
    kv =  %{a: [%Value{val: 3, vc: %{x: 1, y: 1, z: 0}}, %Value{val: 4, vc: %{x: 1, y: 0, z: 1}}], 
                      b: [%Value{val: 7, vc: %{x: 1, y: 1, z: 1}}], 
                      c: [%Value{val: 8, vc: %{x: 1, y: 3, z: 1}}], 
                      d: [%Value{val: 9, vc: %{x: 2, y: 1, z: 1}}]}
    state = %{store: kv, merkle_keys: [], merkle_version: 0, merkle_hashchain: nil}
    state = Merkle.build_and_store_chain(state, kv)
    assert state.merkle_keys == [:a, :b, :c, :d]
    IO.puts("State: #{inspect(state)}")

  end
end

  