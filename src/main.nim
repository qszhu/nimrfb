import std/[
  logging,
  sequtils,
  strformat,
  strutils,
]

import rfbclient
import binio



# const REMOTE_HOST = "10.10.1.2"
const REMOTE_HOST = "192.168.50.56"
const REMOTE_PORT = 5900

proc savePPM(data: var seq[uint8], width, height: int, pf: PixelFormat) =
  var res = newSeq[string]()
  res.add "P3"
  res.add &"{width} {height}"
  res.add "255"
  var i = 0
  for y in 0 ..< height:
    for x in 0 ..< width:
      let p = if pf.bigEndianFlag: data.readUint32(i) else: data.readUint32LE(i)
      let r = p shr pf.redShift and pf.redMax
      let g = p shr pf.greenShift and pf.greenMax
      let b = p shr pf.blueShift and pf.blueMax
      res.add &"{r} {g} {b}"
      i += 4
  writeFile("out.ppm", res.join("\n"))

proc main() {.async} =
  let client = newRFBClient()
  await client.handShake(REMOTE_HOST, REMOTE_PORT, true)

  let sp = client.serverParams
  echo sp
  # await client.sendSetEncodings(@[1000, 1001, 1002, 1011].mapIt(it.int32))
  # await client.sendSetEncodings(@[Encoding.RAW].mapIt(it.int32))
  # await client.sendSetEncodings(@[Encoding.ZLIB].mapIt(it.int32))
  await client.sendSetEncodings(@[Encoding.ZRLE].mapIt(it.int32))

  for _ in 0 ..< 10:
    await client.sendFramebufferUpdateRequest(0, 0, sp.fbWidth, sp.fbHeight, false)
    for (x, y, width, height, fb) in await client.recvFramebufferUpdate:
      echo (x, y, width, height, fb.len)
      # var fb = fb
      # savePPM(fb, width.int, height.int, sp.pixelFormat)



when isMainModule:
  when not defined(release):
    addHandler(newConsoleLogger(levelThreshold = lvlDebug))

  waitFor main()
