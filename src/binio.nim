proc readUint8*(s: string, offset = 0): uint8 {.inline.} =
  s[offset].uint8

proc writeUint8*(n: uint8): string =
  result = newString(1)
  result[0] = n.char

proc readUint8Seq*(s: string, n: int, offset = 0): seq[uint8] =
  result = newSeq[uint8](n)
  for i in 0 ..< n:
    result[i] = s.readUint8(offset + i)

proc writeUint8Seq*(b: seq[uint8]): string =
  result = newString(b.len)
  for i in 0 ..< b.len:
    result[i] = b[i].char

proc readUint16*(s: string, offset = 0): uint16 =
  let hi = s.readUint8(offset)
  let lo = s.readUint8(offset + 1)
  (hi.uint16 shl 8) or lo

proc readUint32*(s: string, offset = 0): uint32 =
  for i in 0 ..< 4:
    result = (result shl 8) or s.readUint8(offset + i)

proc readString*(s: string, n: int, offset = 0): string {.inline.} =
  s[offset ..< offset + n]

proc readBool*(s: string): bool {.inline.} =
  s.readUint8 != 0

proc writeBool*(b: bool): string =
  result = newString(1)
  if b: result[0] = 1.char
