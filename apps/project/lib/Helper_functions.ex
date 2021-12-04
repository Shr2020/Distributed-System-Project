defmodule Helper do
    def check_kv_store_consistent(kv1, kv2) do
        keys1 = Map.keys(kv1)
        sorted_keys1 = Enum.sort(keys1)

        keys2 = Map.keys(kv2)
        sorted_keys2 = Enum.sort(keys2)

        if sorted_keys1 != sorted_keys2 do
            false
        else
            # keys are same . Check for values too
            check_values(sorted_keys1, kv1, kv2) 
        end
    end

    def check_values([head|tail], kv1, kv2) do
        vals1 = elem(Map.fetch(kv1, head), 1)
        vals2 = elem(Map.fetch(kv2, head), 1)
        if check_vals(vals1, vals2) == true do
            check_values(tail, kv1, kv2)
        else
            false
        end
    end

    def check_values([], kv1, kv2) do
        true
    end

    def check_vals([head|tail], vals2) do
        if Enum.member?(vals2, head) do
            vals2 = List.delete(vals2, head)
            check_vals(tail, vals2)
        end
    end

    def check_vals([], [head|tail]) do
        false
    end

    def check_vals([], []) do
        true
    end
end