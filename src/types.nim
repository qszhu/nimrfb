type
  SecurityType* = enum
    DIFFIE_HELLMAN = 30'u8

type
  PixelFormat* = object
    bitsPerPixel*: uint8
    depth*: uint8
    bigEndianFlag*: bool
    trueColourFlag*: bool
    redMax*: uint16
    greenMax*: uint16
    blueMax*: uint16
    redShift*: uint8
    greenShift*: uint8
    blueShift*: uint8

type
  ServerParam* = object
    fbWidth*: uint16
    fbHeight*: uint16
    pixelFormat*: PixelFormat
    name*: string
