import ../binsock



# https://github.com/rfbproto/rfbproto/blob/master/rfbproto.rst#raw-encoding
proc recvRawEncodingFB*(
  sock: AsyncSocket,
  width, height, bitsPerPixel: int
): Future[seq[uint8]] {.async.} =
  let N = width * height * (bitsPerPixel shr 3)
  echo N
  await sock.readUint8Seq(N)
