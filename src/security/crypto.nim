import std/[
  strutils,
]

import checksums/md5

import nimcrypto

import ../binio



proc md5sum*(m: seq[uint8]): seq[uint8] =
  let d = m.writeUint8Seq.getMD5
  for i in countup(0, d.len - 1, 2):
    result.add fromHex[uint8](d[i ..< i + 2])

proc aes128ECBEncrypt*(plain: string, key: string): string =
  doAssert plain.len == 128
  doAssert aes128.sizeKey == key.len
  var ectx: ECB[aes128]
  result = newString(plain.len)
  ectx.init(key)
  ectx.encrypt(plain, result)
  ectx.clear()
