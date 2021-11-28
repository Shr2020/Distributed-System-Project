defmodule MerkleChain do
    def build(state, kv) do
        key_list = Map.keys(kv)
        sorted_keys = Enum.sort(key_list)
        state = Map.put(state, :merkle_key_set, sorted_keys)
        build_chain(sorted_keys, kv, [])
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
    # TODO: change the logic
    def compare_two_trees([head1|tail1], [head2|tail2]) do
        if head1==head2 do
            []
        else
            [head2] ++ compare_two_trees(tail1,tail2) 
        end
    end

    def compare_two_trees([], mk2) do
        mk2
    end

    def compare_two_trees(mk1, []) do
        mk1
    end

    def compare_two_trees([], []) do
        []
    end

    #TODO: function to get the key value map of unmatched hashes
    #def get_unmatched_hashes(kv, matched_hashes_received, merkle_chain, key_list) do
    #end

    def merge_and_resolve_kv(received, kv, state) do
        merged_kv = 
            Map.merge(received, m2, fn _k, v1, v2 ->              
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

    def resolve2(vc_map1, [head|tail], acc) do
        result = Dynamo.compare_vectors(vc_map1, head)
        acc = 
            if result == :concurrent do
                acc |> MapSet.put(vc_map1) |> MapSet.put(head)
            else
                acc =
                    if result == :before do
                        acc |> MapSet.put(head)
                    else
                        acc |> MapSet.put(vc_map1)
                    end
            end
        resolve2(vc_map1, tail, kv, acc)
    end

    def resolve2(vc_map1, [], acc) do
        acc
    end
end