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

    new_map = Merkle.merge_and_resolve_kv(received, kv, state)
    expected_map =  %{a: [%Value{val: 3, vc: %{x: 1, y: 1, z: 0}}, %Value{val: 4, vc: %{x: 1, y: 0, z: 1}}], 
                      b: [%Value{val: 7, vc: %{x: 1, y: 1, z: 1}}], 
                      c: [%Value{val: 8, vc: %{x: 1, y: 3, z: 1}}], 
                      d: [%Value{val: 9, vc: %{x: 2, y: 1, z: 1}}]}
    assert new_map == expected_map
  end
end

  