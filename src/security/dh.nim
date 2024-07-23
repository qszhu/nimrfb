import std/[
  algorithm,
  options,
]

import pkg/bigints



# https://en.wikipedia.org/wiki/Diffie%E2%80%93Hellman_key_exchange#Cryptographic_explanation
type
  DiffieHellmanParams* = object
    generator*: uint16
    keySize*: uint16
    primeModulus*: seq[uint8]
    publicValue*: seq[uint8]

proc initBigInt(data: seq[uint8]): BigInt =
  result = initBigInt(0)
  for b in data:
    result = result shl 8 + initBigInt(b)

proc privateKey*(self: DiffieHellmanParams): BigInt {.inline.} =
  # TODO: secure random
  initBigInt(self.primeModulus) div initBigInt(3)

proc publicKey*(self: DiffieHellmanParams, privKey: BigInt): BigInt {.inline.} =
  initBigInt(self.generator).powmod(privKey, initBigInt(self.primeModulus))

proc sharedSecret*(self: DiffieHellmanParams, privKey: BigInt): BigInt {.inline.} =
  initBigInt(self.publicValue).powmod(privKey, initBigInt(self.primeModulus))



proc toUint8Seq*(x: BigInt): seq[uint8] =
  result = newSeq[uint8]()
  var x = x
  let b = initBigInt(256)
  let z = initBigInt(0)
  while x != z:
    let a = toInt[uint8](x mod b).get
    result.add a
    x = x shr 8
  result.reverse

proc toUint8Seq*(x: BigInt, n: int): seq[uint8] =
  result = newSeq[uint8](n)
  var x = x
  let b = initBigInt(256)
  for i in countdown(n - 1, 0):
    let a = toInt[uint8](x mod b).get
    result[i] = a
    x = x shr 8
