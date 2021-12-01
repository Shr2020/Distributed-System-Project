defmodule Merkle do
    def build_and_store_chain(state, kv) do
        key_list = Map.keys(kv)
        sorted_keys = Enum.sort(key_list)
        state = Map.put(state, :merkle_key_set, sorted_keys)
        state = Map.put(state, :merkle_version, state.merkle_version + 1)
        new_chain = build_chain(sorted_keys, kv, [])
        Map.put(state, :merkle_hash, new_chain)
    end

    def build_chain([head|tail], kv, acc) do
        key_hash = Crypto.sha256(head)
        val_hash = Crypto.sha256(kv.head)
        total_hash = Crypto.sha256(key_hash<>val_hash)
        total_hash_val = Crypto.sha256(total_hash<>Enum.join(acc))
        acc = [MerkleNode.new(total_hash_val)] ++ acc
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
            acc = Map.put(acc, head2, kv.head2)
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
        kv_latest = resolve_map(merged_kv)
        state = Map.put(state, :kv, kv_latest)
    end

    def resolve_map(kv) do
        key_list = Map.keys(kv)
        resolve_key_value(key_list, kv)
    end

    def resolve_key_value([head|tail], kv) do
        val1 = kv.head
        vals = resolve1(val1, val1, MapSet.new())
        kv = Map.put(kv, head, MapSet.to_list(vals))
        resolve_key_value(tail, kv)
    end

    def resolve_key_value([], kv) do
        kv
    end

    def resolve1([head1|tail1], val_list, acc) do
        acc = resolve2(head1, val_list, acc)
        resolve1(tail1, val_list, acc)
    end

    def resolve1([], val_list, acc) do
        acc
    end

    def resolve2(val_vc_1, [head|tail], acc) do
        result = Dynamo.compare_vectors(val_vc_1.vc, head.vc)
        acc = 
            if result == :concurrent do
                acc |> MapSet.put(val_vc_1) |> MapSet.put(head)
            else
                acc =
                    if result == :before do
                        acc |> MapSet.put(head)
                    else
                        acc |> MapSet.put(val_vc_1)
                    end
            end
        resolve2(val_vc_1, tail, acc)
    end

    def resolve2(val_vc_1, [], acc) do
        acc
    end
end