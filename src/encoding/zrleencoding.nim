# https://github.com/rfbproto/rfbproto/blob/master/rfbproto.rst#zrle-encoding
import pkg/nimzlib

import ../binsock



var si: StreamInflator = nil

proc recvZRleEncodingFB*(
  sock: AsyncSocket,
  width, height, bitsPerPixel: int
): Future[seq[uint8]] {.async.} =
  # TODO: streaming
  # TODO: DRY
  let N = await sock.readUint32
  echo N
  var buf = await sock.readString(N)
  let bs = newStringStream(buf)
  buf =
    if si == nil:
      si = newStreamInflator(bs)
      si.inflate.readAll
    else:
      si.inflate(bs).readAll

  let bytesPerPixel = bitsPerPixel shr 3
  let stride = width * bytesPerPixel
  result = newSeq[uint8](height * stride)
  var i = 0
  for r in countup(0, height - 1, 64):
    for c in countup(0, width - 1, 64):
      let t = buf.readUint8(i)
      let (a, b) = (t and 0x80, t and 0x7f)
      if a == 0:
        var (r1, c1) = (r, c)
        for _ in 0 ..< 64:
          if r1 >= height: break
          for _ in 0 ..< 64:
            if c1 >= width: break
            let r = buf.readUint8(i)
            let g = buf.readUint8(i)
            let b = buf.readUint8(i)
            let o = r1 * stride + c1 * bytesPerPixel
            result[o] = r
            result[o + 1] = g
            result[o + 2] = b
            c1 += 1
          r1 += 1
          c1 = c
      else:
        raise newException(ValueError, $(a, b))
