import std/[
  strformat,
  strutils,
]

import binsock
import security/[crypto, dh]
import types

export asyncdispatch, types



type
  RFBClient* = ref object
    host: string
    port: Port
    sock: AsyncSocket

proc newRFBClient*(host: string, p: int): RFBClient =
  result.new
  result.host = host
  result.port = Port(p)

proc connect*(self: RFBClient) {.async.} =
  self.sock = newAsyncSocket()
  await self.sock.connect(self.host, self.port)

proc recvVersion*(self: RFBClient): Future[(int, int)] {.async.} =
  let s = await self.sock.readString(12)
  doAssert s[0 ..< 3] == "RFB"
  let major = s[4 .. 6].parseInt
  let minor = s[8 .. 10].parseInt
  (major, minor)

proc sendVersion*(self: RFBClient, major, minor: int) {.async.} =
  let s = &"RFB {major:03}.{minor:03}\n"
  await self.sock.writeString(s)

proc recvSecurityTypes*(self: RFBClient): Future[seq[uint8]] {.async.} =
  let n = await self.sock.readUint8
  return await self.sock.readUint8Seq(n)

proc sendSecurityType*(self: RFBClient, secType: SecurityType) {.async.} =
  await self.sock.writeUint8(secType.uint8)

proc recvDiffieHellmanParams*(self: RFBClient): Future[DiffieHellmanParams] {.async.} =
  var params: DiffieHellmanParams

  params.generator = await self.sock.readUint16
  params.keySize = await self.sock.readUint16
  params.primeModulus = await self.sock.readUint8Seq(params.keySize)
  params.publicValue = await self.sock.readUint8Seq(params.keySize)

  return params

proc packUserCredentials(username, password: string): string =
  result = newString(128)
  copyMem(addr result[0], addr username[0], username.len)
  copyMem(addr result[64], addr password[0], password.len)

proc sendUserCredentials*(self: RFBClient, dh: DiffieHellmanParams, username, password: string) {.async.} =
  doAssert dh.keySize == 128
  let privKey = dh.privateKey
  let secret = dh.sharedSecret(privKey)
  let encKey = md5sum(secret.toUint8Seq)

  let data = aes128ECBEncrypt(packUserCredentials(username, password), encKey.writeUint8Seq)

  let pubKey = dh.publicKey(privKey)

  await self.sock.writeString(data)
  await self.sock.writeUint8Seq(pubKey.toUint8Seq(dh.keySize.int))

proc recvSecurityResult*(self: RFBClient): Future[(uint32, string)] {.async.} =
  let sr = await self.sock.readUint32
  case sr:
  of 0:
    (sr, "OK")
  of 1:
    let n = await self.sock.readUint32
    let rs = await self.sock.readString(n)
    self.sock.close()
    (sr, rs)
  of 2:
    self.sock.close()
    (sr, "Too many attempts")
  else:
    self.sock.close()
    raise newException(ValueError, &"Unknown security result: {sr}")

proc sendClientInit*(self: RFBClient, sharedFlag = true) {.async.} =
  await self.sock.writeBool sharedFlag

proc recvPixelFormat(self: RFBClient): Future[PixelFormat] {.async.} =
  var pixelFormat: PixelFormat

  pixelFormat.bitsPerPixel = await self.sock.readUint8
  pixelFormat.depth = await self.sock.readUint8
  pixelFormat.bigEndianFlag = await self.sock.readBool
  pixelFormat.trueColourFlag = await self.sock.readBool
  pixelFormat.redMax = await self.sock.readUint16
  pixelFormat.greenMax = await self.sock.readUint16
  pixelFormat.blueMax = await self.sock.readUint16
  pixelFormat.redShift = await self.sock.readUint8
  pixelFormat.greenShift = await self.sock.readUint8
  pixelFormat.blueShift = await self.sock.readUint8

  await self.sock.skip(3)
  return pixelFormat

proc recvServerInit*(self: RFBClient): Future[ServerParam] {.async.} =
  var serverParam: ServerParam

  serverParam.fbWidth = await self.sock.readUint16
  serverParam.fbHeight = await self.sock.readUint16
  serverParam.pixelFormat = await self.recvPixelFormat

  let n = await self.sock.readUint32
  serverParam.name = await self.sock.readString(n)

  return serverParam
