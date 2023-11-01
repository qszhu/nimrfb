import std/[
  logging,
]

import rfbclient



const REMOTE_HOST = "10.10.1.2"
const REMOTE_PORT = 5900

proc main() {.async} =
  let client = newRFBClient()
  let serverParams = await client.handShake(REMOTE_HOST, REMOTE_PORT)

  echo serverParams



when isMainModule:
  when not defined(release):
    addHandler(newConsoleLogger(levelThreshold = lvlDebug))

  waitFor main()
