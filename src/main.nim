import std/[
  rdstdin,
  terminal,
]

import rfbclient



const REMOTE_HOST = "10.10.1.2"
const REMOTE_PORT = 5900

proc main() {.async} =
  let client = newRFBClient(REMOTE_HOST, REMOTE_PORT)
  await client.connect

  let (major, minor) = await client.recvVersion
  echo (major, minor)
  await client.sendVersion(major, minor)

  let secTypes = await client.recvSecurityTypes
  echo secTypes
  await client.sendSecurityType(DIFFIE_HELLMAN)

  let params = await client.recvDiffieHellmanParams
  echo params

  let username = readLineFromStdin("Username: ")
  let password = readPasswordFromStdin("Password: ")
  await client.sendUserCredentials(params, username, password)

  block:
    let (ok, errMsg) = await client.recvSecurityResult
    if ok != 0:
      echo errMsg
      return

  await client.sendClientInit()
  echo await client.recvServerInit()



when isMainModule:
  waitFor main()
