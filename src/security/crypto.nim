import std/[
  strutils,
]

import pkg/checksums/md5
import pkg/nimtestcrypto

import ../binio



proc md5sum*(m: var seq[uint8]): seq[uint8] =
  let d = m.writeUint8Seq.getMD5
  for i in countup(0, d.len - 1, 2):
    result.add fromHex[uint8](d[i ..< i + 2])

proc aes128ECBEncrypt*(plain: string, key: string): string =
  doAssert plain.len == 128
  cast[string](encryptAES128ECB(cast[seq[uint8]](plain), cast[seq[uint8]](key)))[0 ..< 128]
