defmodule MerkeTree do
    def build(kv) do
        key_list = Map.keys(kv)
        sorted_keys = Enum.sort(key_list)
        build_chain(sorted_keys, kv, [])
    end

    def build_chain(head|tail, kv, acc) do
        key_hash = Crypto.sha256(head)
        val_hash = Crypto.sha256(kv.head)
        total_hash = Crypto.sha256(key_hash<>val_sh)
        acc = acc ++ [MerkelNode.new(total_hash)]
        build_chain(tail, kv, acc)
    end

    def build_chain([], kv, acc) do
        acc
    end

    def compare_two_trees(mk1, mk2) do

    end
end