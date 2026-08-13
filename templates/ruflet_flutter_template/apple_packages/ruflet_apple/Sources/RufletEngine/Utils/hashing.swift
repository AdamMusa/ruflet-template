func fnv1aHash(_ bytes: [UInt8]) -> UInt32 {
    let fnvOffset: UInt32 = 0x811c9dc5
    let fnvPrime: UInt32 = 0x01000193
    return bytes.reduce(fnvOffset) { hash, byte in
        (hash ^ UInt32(byte)) &* fnvPrime
    }
}
