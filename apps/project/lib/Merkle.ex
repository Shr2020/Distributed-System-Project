defmodule MerkleChain do
    def build(kv) do
        key_list = Map.keys(kv)
        sorted_keys = Enum.sort(key_list)
        build_chain(sorted_keys, kv, [])
    end

    def build_chain([head|tail], kv, acc) do
        key_hash = Crypto.sha256(head)
        val_hash = Crypto.sha256(kv.head)
        total_hash = Crypto.sha256(key_hash<>val_hash)
        acc = acc ++ [MerkleNode.new(total_hash)]
        build_chain(tail, kv, acc)
    end

    def build_chain([], kv, acc) do
        acc
    end


    def compare_two_trees([head1|tail1], [head2|tail2]) do
    
        if head1==head2 do
            []
        else
          compare_two_trees(tail1,tail2) ++ head2

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
end