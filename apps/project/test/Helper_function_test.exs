defmodule MerkleTest do
  use ExUnit.Case
  doctest Merkle

  test "is_kv_consistent" do
      kv1 = %{a: [%Value{val: 3, vc: %{x: 1, y: 1, z: 0}}, %Value{val: 4, vc: %{x: 1, y: 0, z: 1}}], 
                      b: [%Value{val: 7, vc: %{x: 1, y: 1, z: 1}}, %Value{val: 8, vc: %{x: 1, y: 2, z: 1}},  %Value{val: 9, vc: %{x: 1, y: 1, z: 1}}], 
                      c: [%Value{val: 8, vc: %{x: 1, y: 3, z: 1}}], 
                      d: [%Value{val: 9, vc: %{x: 2, y: 1, z: 1}}]}

      kv2 = %{a: [%Value{val: 4, vc: %{x: 1, y: 0, z: 1}}, %Value{val: 3, vc: %{x: 1, y: 1, z: 0}}, ], 
                      b: [%Value{val: 8, vc: %{x: 1, y: 2, z: 1}}, %Value{val: 7, vc: %{x: 1, y: 1, z: 1}}, %Value{val: 9, vc: %{x: 1, y: 1, z: 1}}], 
                      c: [%Value{val: 8, vc: %{x: 1, y: 3, z: 1}}], 
                      d: [%Value{val: 9, vc: %{x: 2, y: 1, z: 1}}]}

      assert Helper.check_kv_store_consistent(kv1, kv2) == true 

      kv1 = %{a: [%Value{val: 3, vc: %{x: 1, y: 1, z: 0}}, %Value{val: 4, vc: %{x: 1, y: 0, z: 1}}], 
                      b: [%Value{val: 10, vc: %{x: 1, y: 2, z: 1}},  %Value{val: 9, vc: %{x: 1, y: 1, z: 1}}], 
                      c: [%Value{val: 8, vc: %{x: 1, y: 3, z: 1}}], 
                      d: [%Value{val: 9, vc: %{x: 2, y: 1, z: 1}}]}

      kv2 = %{a: [%Value{val: 4, vc: %{x: 1, y: 0, z: 1}}, %Value{val: 3, vc: %{x: 1, y: 1, z: 0}}, ], 
                      b: [%Value{val: 8, vc: %{x: 1, y: 2, z: 1}}, %Value{val: 7, vc: %{x: 1, y: 1, z: 1}}, %Value{val: 9, vc: %{x: 1, y: 1, z: 1}}], 
                      c: [%Value{val: 8, vc: %{x: 1, y: 3, z: 1}}], 
                      d: [%Value{val: 9, vc: %{x: 2, y: 1, z: 1}}]}

      assert Helper.check_kv_store_consistent(kv1, kv2) == false

      kv1 = %{a: [%Value{val: 3, vc: %{x: 1, y: 1, z: 0}}, %Value{val: 4, vc: %{x: 1, y: 0, z: 1}}], 
                      b: [%Value{val: 10, vc: %{x: 1, y: 2, z: 1}},  %Value{val: 9, vc: %{x: 1, y: 1, z: 1}}], 
                      c: [%Value{val: 8, vc: %{x: 1, y: 3, z: 1}}], 
                      d: [%Value{val: 9, vc: %{x: 2, y: 1, z: 1}}]}

      kv2 = %{a: [%Value{val: 4, vc: %{x: 1, y: 0, z: 1}}, %Value{val: 3, vc: %{x: 1, y: 1, z: 0}}, ], 
                      b: [%Value{val: 8, vc: %{x: 1, y: 2, z: 1}}, %Value{val: 7, vc: %{x: 1, y: 1, z: 1}}, %Value{val: 9, vc: %{x: 1, y: 1, z: 1}}], 
                      c: [%Value{val: 8, vc: %{x: 1, y: 3, z: 1}}]}

      assert Helper.check_kv_store_consistent(kv1, kv2) == false
  end

  test "all_kv_consistent" do
    kv1 = %{a: [%Value{val: 3, vc: %{x: 1, y: 1, z: 0}}, %Value{val: 4, vc: %{x: 1, y: 0, z: 1}}], 
                      b: [%Value{val: 7, vc: %{x: 1, y: 1, z: 1}}, %Value{val: 8, vc: %{x: 1, y: 2, z: 1}},  %Value{val: 9, vc: %{x: 1, y: 1, z: 1}}], 
                      c: [%Value{val: 8, vc: %{x: 1, y: 3, z: 1}}], 
                      d: [%Value{val: 9, vc: %{x: 2, y: 1, z: 1}}]}

    kv2 = %{a: [%Value{val: 4, vc: %{x: 1, y: 0, z: 1}}, %Value{val: 3, vc: %{x: 1, y: 1, z: 0}}, ], 
                    b: [%Value{val: 8, vc: %{x: 1, y: 2, z: 1}}, %Value{val: 7, vc: %{x: 1, y: 1, z: 1}}, %Value{val: 9, vc: %{x: 1, y: 1, z: 1}}], 
                    c: [%Value{val: 8, vc: %{x: 1, y: 3, z: 1}}], 
                    d: [%Value{val: 9, vc: %{x: 2, y: 1, z: 1}}]}
                
    kv3 = %{a: [%Value{val: 4, vc: %{x: 1, y: 0, z: 1}}, %Value{val: 3, vc: %{x: 1, y: 1, z: 0}}, ], 
                    b: [%Value{val: 8, vc: %{x: 1, y: 2, z: 1}}, %Value{val: 7, vc: %{x: 1, y: 1, z: 1}}, %Value{val: 9, vc: %{x: 1, y: 1, z: 1}}],  
                    d: [%Value{val: 9, vc: %{x: 2, y: 1, z: 1}}],
                    c: [%Value{val: 8, vc: %{x: 1, y: 3, z: 1}}]}

    assert Helper.ckeck_all_kv_consistent([kv1, kv2, kv3], [kv1, kv2, kv3]) == true

    kv1 = %{a: [%Value{val: 3, vc: %{x: 1, y: 1, z: 0}}, %Value{val: 4, vc: %{x: 1, y: 0, z: 1}}], 
                      b: [%Value{val: 7, vc: %{x: 1, y: 1, z: 1}}, %Value{val: 8, vc: %{x: 1, y: 2, z: 1}},  %Value{val: 9, vc: %{x: 1, y: 1, z: 1}}], 
                      c: [%Value{val: 8, vc: %{x: 1, y: 3, z: 1}}], 
                      d: [%Value{val: 9, vc: %{x: 2, y: 1, z: 1}}]}

    kv2 = %{a: [%Value{val: 4, vc: %{x: 1, y: 0, z: 1}}, %Value{val: 3, vc: %{x: 1, y: 1, z: 0}}, ], 
                    b: [%Value{val: 8, vc: %{x: 1, y: 2, z: 1}}, %Value{val: 7, vc: %{x: 1, y: 1, z: 1}}, %Value{val: 9, vc: %{x: 1, y: 1, z: 1}}], 
                    c: [%Value{val: 8, vc: %{x: 1, y: 3, z: 1}}], 
                    d: [%Value{val: 9, vc: %{x: 2, y: 1, z: 1}}]}

    kv3 = %{a: [%Value{val: 3, vc: %{x: 1, y: 1, z: 0}}, %Value{val: 4, vc: %{x: 1, y: 0, z: 1}}], 
                      b: [%Value{val: 10, vc: %{x: 1, y: 2, z: 1}},  %Value{val: 9, vc: %{x: 1, y: 1, z: 1}}], 
                      c: [%Value{val: 8, vc: %{x: 1, y: 3, z: 1}}], 
                      d: [%Value{val: 9, vc: %{x: 2, y: 1, z: 1}}]}

    kv4 = %{a: [%Value{val: 4, vc: %{x: 1, y: 0, z: 1}}, %Value{val: 3, vc: %{x: 1, y: 1, z: 0}}, ], 
                      b: [%Value{val: 8, vc: %{x: 1, y: 2, z: 1}}, %Value{val: 7, vc: %{x: 1, y: 1, z: 1}}, %Value{val: 9, vc: %{x: 1, y: 1, z: 1}}], 
                      c: [%Value{val: 8, vc: %{x: 1, y: 3, z: 1}}]}

    assert Helper.ckeck_all_kv_consistent([kv1, kv2, kv3, kv4], [kv1, kv2, kv3, kv4]) == false
  end
end