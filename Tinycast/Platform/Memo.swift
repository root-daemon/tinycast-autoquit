/// Bounded memo. The key must name every dependency, since nothing else invalidates a slot.
/// Eight slots cover a typed prefix chain and its backspaces; values stay tiny by contract.
struct Memo<Key: Equatable, Value> {
    private var slots: [(key: Key, value: Value)] = []

    mutating func value(for key: Key, build: () -> Value) -> Value {
        if let index = slots.firstIndex(where: { $0.key == key }) {
            let hit = slots.remove(at: index)
            slots.insert(hit, at: 0)
            return hit.value
        }
        let built = build()
        slots.insert((key, built), at: 0)
        if slots.count > 8 { slots.removeLast(slots.count - 8) }
        return built
    }
}
