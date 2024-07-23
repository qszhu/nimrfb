type
  SecurityType* = enum
    DIFFIE_HELLMAN = 30

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
  ServerParams* = object
    fbWidth*: uint16
    fbHeight*: uint16
    pixelFormat*: PixelFormat
    name*: string

type
  Encoding* = enum
    RAW = 0
    ZLIB = 6
    ZRLE = 16
