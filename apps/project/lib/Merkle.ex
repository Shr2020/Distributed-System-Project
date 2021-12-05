defmodule Merkle do
    def build_and_store_chain(state, kv) do
        key_list = Map.keys(kv)
        sorted_keys = Enum.sort(key_list)
        state = Map.put(state, :merkle_keys, sorted_keys)
        state = Map.put(state, :merkle_version, state.merkle_version + 1)
        new_chain = build_chain(sorted_keys, kv, [])
        #IO.puts("New chain: #{inspect(new_chain)}\n")
        Map.put(state, :merkle_hashchain, new_chain)
    end

    def build_chain([head|tail], kv, acc) do
        key_hash = Crypto.sha256(head)
        val = Map.fetch(kv, head)
        val_hash = Crypto.sha256(elem(val, 1))
        total_hash = Crypto.sha256(key_hash<>val_hash)
        total_hash_val = Crypto.sha256(total_hash<>Enum.join(acc))
        acc = [total_hash_val] ++ acc
        build_chain(tail, kv, acc)
    end

    def build_chain([], kv, acc) do
        acc
    end

    # First argument is the tree received from other node for synchronisation.
    # The return value are the matched hashes between the two lists
    def compare_two_chains(hashchain1, hashchain2) do
        matched_hashes = compare_two_chains(hashchain1, hashchain2, [])
    end

    def compare_two_chains([head1|tail1], hashchain2, acc) do
        acc =
        if Enum.member?(hashchain2, head1) do
            acc = acc ++ [head1|tail1]
        else
            compare_two_chains(tail1, hashchain2, acc)
        end
    end

    def compare_two_chains([], hashchain2, acc) do
        acc
    end

    #function to get the key value map of unmatched hashes
    def get_unmatched_elements(kv, [], merkle_chain, key_list) do
        kv
    end

    def get_unmatched_elements(kv, [head|tail], merkle_chain, key_list) do
        get_unmatched_elements(kv, head, merkle_chain, key_list, %{})
    end

    def get_unmatched_elements(kv, head, [head1|tail1], [head2|tail2], acc) do
        if head == head1 do
            acc
        else
            res = Map.fetch(kv, head2)
            acc = Map.put(acc, head2, elem(res, 1))
            get_unmatched_elements(kv, head, tail1, tail2, acc)
        end
    end

    def get_unmatched_elements(kv, head, [], [], acc) do
        :merkle_error
    end

    # resolve the kv map with entries received for synchronization
    def merge_and_resolve_kv(received, kv, state) do
        merged_kv = 
            Map.merge(received, kv, fn _k, v1, v2 ->              
                if v1 == v2 do
                    v1
                else
                    v1 ++ v2
                end
            end)
        kv_latest = resolve_map(merged_kv, %{})
        IO.puts("*********** #{inspect(kv_latest)}\n")
        state = Map.put(state, :store, kv_latest)
    end

    def resolve_map(kv, new_kv) do
        key_list = Map.keys(kv)
        resolve_key_value(key_list, kv, new_kv)
    end

    def resolve_key_value([head|tail], kv, new_kv) do
        val1 = elem(Map.fetch(kv, head), 1)
        vals = resolve1(val1, val1, MapSet.new(), MapSet.new())
        list_vals = MapSet.to_list(vals)
        new_kv = Map.put(new_kv, head, list_vals)
        resolve_key_value(tail, kv, new_kv)
    end

    def resolve_key_value([], kv, new_kv) do
        new_kv
    end

    def resolve1([head1|tail1], val_list, acc, before_acc) do
        acc = resolve2(head1, val_list, acc, before_acc)
        resolve1(tail1, val_list, acc, before_acc)
    end

    def resolve1([], val_list, acc, before_acc) do
        acc
    end

    def resolve2(val_vc_1, [head|tail], acc, before_acc) do
        result = Dynamo.compare_vectors(val_vc_1.vc, head.vc)
        acc = 
            if result == :concurrent do
                acc = 
                    if Enum.member?(before_acc, val_vc_1) or Enum.member?(before_acc, head) do
                        acc
                    else
                        acc |> MapSet.put(val_vc_1) |> MapSet.put(head)
                    end
                resolve2(val_vc_1, tail, acc, before_acc)
            else
                acc =
                    if result == :before do
                        acc = MapSet.delete(acc, val_vc_1)
                        before_acc = before_acc |> MapSet.put(val_vc_1)
                        acc |> MapSet.put(head)
                        resolve2(val_vc_1, tail, acc, before_acc)
                    else
                        acc = MapSet.delete(acc, head)
                        before_acc = before_acc |> MapSet.put(head)
                        acc |> MapSet.put(val_vc_1)
                        resolve2(val_vc_1, tail, acc, before_acc)
                    end
            end
    end

    def resolve2(val_vc_1, [], acc, before_acc) do
        acc
    end
end