proc readUint8*(s: string, offset = 0): uint8 {.inline.} =
  s[offset].uint8

proc readUint8*(s: string, offset: var int): uint8 {.inline.} =
  result = s[offset].uint8
  offset += 1

proc writeUint8*(n: uint8): string =
  result = newString(1)
  result[0] = n.char

proc readUint8Seq*(s: var string, n: int, offset = 0): seq[uint8] =
  result = newSeq[uint8](n)
  for i in 0 ..< n:
    result[i] = s.readUint8(offset + i)

proc writeUint8Seq*(b: seq[uint8]): string =
  result = newString(b.len)
  for i in 0 ..< b.len:
    result[i] = b[i].char

proc readUint16*(s: var string, offset = 0): uint16 =
  let hi = s.readUint8(offset)
  let lo = s.readUint8(offset + 1)
  (hi.uint16 shl 8) or lo

proc writeUint16*(n: uint16): string =
  result = newString(2)
  result[0] = (n shr 8 and 0xff).char
  result[1] = (n and 0xff).char

proc readUint32*(s: var string, offset = 0): uint32 =
  for i in 0 ..< 4:
    result = (result shl 8) or s.readUint8(offset + i)

proc readUint32*(a: var seq[uint8], offset = 0): uint32 =
  for i in 0 ..< 4:
    result = (result shl 8) or a[offset + i]

proc readUint32LE*(s: var string, offset = 0): uint32 =
  for i in countdown(3, 0):
    result = (result shl 8) or s.readUint8(offset + i)

proc readUint32LE*(a: var seq[uint8], offset = 0): uint32 =
  for i in countdown(3, 0):
    result = (result shl 8) or a[offset + i]

proc writeUint32*(n: uint32): string =
  result = newString(4)
  result[0] = (n shr 24 and 0xff).char
  result[1] = (n shr 16 and 0xff).char
  result[2] = (n shr 8 and 0xff).char
  result[3] = (n and 0xff).char

proc readInt32*(s: var string, offset = 0): int32 =
  let a = s.readUint8Seq(4, offset)
  let neg = (a[0] and 0x80) != 0
  if not neg:
    for b in a:
      result = (result shl 8) or b.int32
  else:
    for b in a:
      result = (result shl 8) or (not b).int32
    result = -(result + 1)

proc writeInt32*(n: int32): string =
  result = newString(4)
  result[0] = (n shr 24 and 0xff).char
  result[1] = (n shr 16 and 0xff).char
  result[2] = (n shr 8 and 0xff).char
  result[3] = (n and 0xff).char

proc readString*(s: var string, n: int, offset = 0): string {.inline.} =
  s[offset ..< offset + n]

proc readBool*(s: var string): bool {.inline.} =
  s.readUint8 != 0

proc writeBool*(b: bool): string =
  result = newString(1)
  if b: result[0] = '\x01'



when isMainModule:
  import std/[sequtils, strformat, strutils]

  block:
    for b in @[0, 1, 0xff].mapIt(it.uint8):
      var s = b.writeUint8
      doAssert s == &"{b.char}"
      doAssert s.readUint8 == b

  block:
    var b = @[0, 1, 0xff].mapIt(it.uint8)
    var s = b.writeUint8Seq
    doAssert s == b.mapIt(it.char).join
    doAssert s.readUint8Seq(b.len) == b

  block:
    let b: uint16 = 0x102
    var s = b.writeUint16
    doAssert s == "\x01\x02"
    doAssert s.readUint16 == b

  block:
    let b: uint32 = 0x1020304
    var s = b.writeUint32
    doAssert s == "\x01\x02\x03\x04"
    doAssert s.readUint32 == b

  block:
    let b: int32 = 0x1020304
    var s = b.writeInt32
    doAssert s == "\x01\x02\x03\x04"
    doAssert s.readInt32 == b

  block:
    let b: int32 = -0x1020304
    var s = b.writeInt32
    doAssert s == "\xfe\xfd\xfc\xfc"
    doAssert s.readInt32 == b

  block:
    let b = true
    var s = b.writeBool
    doAssert s == "\x01"
    doAssert s.readBool == b

  block:
    let b = false
    var s = b.writeBool
    doAssert s == "\x00"
    doAssert s.readBool == b

  echo "ok"