import std/[
  logging,
  rdstdin,
  strformat,
  strutils,
  terminal,
]

import binsock
import encoding/[rawencoding, zlibencoding, zrleencoding]
import security/[crypto, dh]
import types

export asyncdispatch, types



type
  RFBClient* = ref object
    sock: AsyncSocket
    serverParams*: ServerParams

proc newRFBClient*(): RFBClient =
  result.new


# https://github.com/rfbproto/rfbproto/blob/master/rfbproto.rst#protocolversion
proc recvVersion(self: RFBClient): Future[(int, int)] {.async.} =
  let s = await self.sock.readString(12)
  doAssert s[0 ..< 3] == "RFB"
  let major = s[4 .. 6].parseInt
  let minor = s[8 .. 10].parseInt
  (major, minor)

proc sendVersion(self: RFBClient, major, minor: int) {.async.} =
  let s = &"RFB {major:03}.{minor:03}\n"
  await self.sock.writeString(s)



# https://github.com/rfbproto/rfbproto/blob/master/rfbproto.rst#security
proc recvSecurityTypes(self: RFBClient): Future[seq[uint8]] {.async.} =
  let n = await self.sock.readUint8
  if n != 0:
    return await self.sock.readUint8Seq(n)

  let rLen = await self.sock.readUint32
  return cast[seq[uint8]](await self.sock.readString(rLen))

proc sendSecurityType(self: RFBClient, secType: SecurityType) {.async.} =
  await self.sock.writeUint8(secType.uint8)



# https://github.com/rfbproto/rfbproto/blob/master/rfbproto.rst#diffie-hellman-authentication
proc recvDiffieHellmanParams(self: RFBClient): Future[DiffieHellmanParams] {.async.} =
  var params: DiffieHellmanParams

  params.generator = await self.sock.readUint16
  params.keySize = await self.sock.readUint16
  params.primeModulus = await self.sock.readUint8Seq(params.keySize)
  params.publicValue = await self.sock.readUint8Seq(params.keySize)

  return params

proc sendUserCredentials(self: RFBClient, dh: DiffieHellmanParams, username, password: string) {.async.} =
  doAssert dh.keySize == 128
  let privKey = dh.privateKey
  var secret = dh.sharedSecret(privKey).toUint8Seq
  var encKey = secret.md5sum

  proc packUserCredentials(username, password: string): string =
    result = newString(128)
    copyMem(result[0].addr, username[0].addr, username.len)
    copyMem(result[64].addr, password[0].addr, password.len)

  let data = aes128ECBEncrypt(packUserCredentials(username, password), encKey.writeUint8Seq)

  var pubKey = dh.publicKey(privKey).toUint8Seq(dh.keySize.int)

  await self.sock.writeString(data)
  await self.sock.writeUint8Seq(pubKey)

# https://github.com/rfbproto/rfbproto/blob/master/rfbproto.rst#securityresult
proc recvSecurityResult(self: RFBClient): Future[(uint32, string)] {.async.} =
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



# https://github.com/rfbproto/rfbproto/blob/master/rfbproto.rst#clientinit
proc sendClientInit(self: RFBClient, sharedFlag = true) {.async.} =
  await self.sock.writeBool sharedFlag

# https://github.com/rfbproto/rfbproto/blob/master/rfbproto.rst#serverinit
proc recvPixelFormat(self: RFBClient): Future[PixelFormat] {.async.}
proc recvServerInit(self: RFBClient): Future[ServerParams] {.async.} =
  var serverParams: ServerParams

  serverParams.fbWidth = await self.sock.readUint16
  serverParams.fbHeight = await self.sock.readUint16
  serverParams.pixelFormat = await self.recvPixelFormat

  let n = await self.sock.readUint32
  serverParams.name = await self.sock.readString(n)

  return serverParams

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
  pixelFormat



proc handShake*(self: RFBClient,
  remoteHost: string,
  remotePort: int,
  sharedFlag = true
) {.async.} =
  self.sock = newAsyncSocket()
  await self.sock.connect(remoteHost, Port(remotePort))

  let (major, minor) = await self.recvVersion
  logging.debug &"Version: {major}.{minor}"
  doAssert major == 3
  doAssert minor >= 8
  await self.sendVersion(3, 8)

  let secTypes = await self.recvSecurityTypes
  logging.debug &"Security types: {secTypes}"
  doAssert DIFFIE_HELLMAN.uint8 in secTypes
  await self.sendSecurityType(DIFFIE_HELLMAN)

  let dhParams = await self.recvDiffieHellmanParams
  logging.debug &"Diffie-Hellman params: {dhParams}"

  let username = readLineFromStdin("Username: ")
  let password = readPasswordFromStdin("Password: ")
  await self.sendUserCredentials(dhParams, username, password)

  block:
    let (ok, errMsg) = await self.recvSecurityResult
    if ok != 0:
      raise newException(ValueError, &"Security error: {errMsg}")

  await self.sendClientInit(sharedFlag)
  self.serverParams = await self.recvServerInit

# https://github.com/rfbproto/rfbproto/blob/master/rfbproto.rst#setencodings
proc sendSetEncodings*(self: RFBClient,
  encodings: seq[int32],
) {.async.} =
  await self.sock.writeUint8(2)
  await self.sock.writeUint8(0)
  await self.sock.writeUint16(encodings.len.uint16)
  for e in encodings:
    await self.sock.writeInt32(e)

# https://github.com/rfbproto/rfbproto/blob/master/rfbproto.rst#framebufferupdaterequest
proc sendFramebufferUpdateRequest*(self: RFBClient,
  x, y, width, height: uint16,
  incremental = true
) {.async.} =
  await self.sock.writeUint8(3)
  await self.sock.writeBool(incremental)
  await self.sock.writeUint16(x)
  await self.sock.writeUint16(y)
  await self.sock.writeUint16(width)
  await self.sock.writeUint16(height)

# https://github.com/rfbproto/rfbproto/blob/master/rfbproto.rst#framebufferupdate
proc recvFramebufferUpdate*(self: RFBClient): Future[seq[(uint16, uint16, uint16, uint16, seq[uint8])]] {.async.}=
  let t = await self.sock.readUint8
  doAssert t == 0
  await self.sock.skip(1)

  let pf = self.serverParams.pixelFormat
  let n = await self.sock.readUint16
  for i in 0 ..< n.int:
    let x = await self.sock.readUint16
    let y = await self.sock.readUint16
    let width = await self.sock.readUint16
    let height = await self.sock.readUint16
    let et = await self.sock.readInt32
    echo (x, y, width, height, et)

    case et:
    of RAW.int32:
      result.add (x, y, width, height,
        await recvRawEncodingFB(self.sock, width.int, height.int, pf.bitsPerPixel.int)
      )
    of ZLIB.int32:
      result.add (x, y, width, height,
        await recvZlibEncodingFB(self.sock, width.int, height.int, pf.bitsPerPixel.int)
      )
    of ZRLE.int32:
      result.add (x, y, width, height,
        await recvZRleEncodingFB(self.sock, width.int, height.int, pf.bitsPerPixel.int)
      )
    else:
      raise newException(ValueError, &"Unknown encoding: {et}")
