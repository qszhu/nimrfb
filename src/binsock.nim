import std/[
  asyncdispatch,
  asyncnet,
]

import binio

export asyncdispatch, asyncnet, binio



proc skip*(sock: AsyncSocket, n: SomeInteger) {.async, inline.} =
  discard await sock.recv(n.int)

proc readString*(sock: AsyncSocket, n: SomeInteger): Future[string] {.async.} =
  let n = n.int
  let buf = await sock.recv(n)
  buf.readString(n)

proc writeString*(sock: AsyncSocket, s: string) {.async, inline.} =
  await sock.send(s)

proc readUint8*(sock: AsyncSocket): Future[uint8] {.async.} =
  let buf = await sock.recv(1)
  buf.readUint8

proc writeUint8*(sock: AsyncSocket, b: uint8) {.async, inline.} =
  await sock.send(b.writeUint8)

proc readUint8Seq*(sock: AsyncSocket, n: SomeInteger): Future[seq[uint8]] {.async.} =
  let n = n.int
  let buf = await sock.recv(n)
  buf.readUint8Seq(n)

proc writeUint8Seq*(sock: AsyncSocket, bs: seq[uint8]) {.async.} =
  await sock.send bs.writeUint8Seq

proc readUint16*(sock: AsyncSocket): Future[uint16] {.async.} =
  let buf = await sock.recv(2)
  buf.readUint16

proc readUint32*(sock: AsyncSocket): Future[uint32] {.async.} =
  let buf = await sock.recv(4)
  buf.readUint32

proc readBool*(sock: AsyncSocket): Future[bool] {.async.} =
  let buf = await sock.readString(1)
  buf.readBool

proc writeBool*(sock: AsyncSocket, b: bool) {.async.} =
  await sock.send b.writeBool
