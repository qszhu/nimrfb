# https://github.com/rfbproto/rfbproto/blob/master/rfbproto.rst#zlib-encoding
import pkg/nimzlib

import ../binsock



var si: StreamInflator = nil

proc recvZlibEncodingFB*(
  sock: AsyncSocket,
  width, height, bitsPerPixel: int
): Future[seq[uint8]] {.async.} =
  # TODO: streaming
  let N = await sock.readUint32
  echo N
  var buf = await sock.readString(N)
  let bs = newStringStream(buf)
  if si == nil:
    si = newStreamInflator(bs)
    cast[seq[uint8]](si.inflate.readAll)
  else:
    cast[seq[uint8]](si.inflate(bs).readAll)
