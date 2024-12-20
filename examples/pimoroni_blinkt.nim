# example to run on Pimoroni Blinkt!
# compile and load dtoverlay blinkt from overlays folder first!

import std/times
import std/os
import std/math
import std/osproc
import std/strutils

import spidev

type
  Hsv* = object
    h*, s*, v*: float

  Pixel* = object
    r*: uint8
    g*: uint8
    b*: uint8
    brightness*: uint8

func constructPixel*(r, g, b: float): Pixel =
  result.r = uint8 round(r * 255.0f)
  result.g = uint8 round(g * 255.0f)
  result.b = uint8 round(b * 255.0f)
  result.brightness = 1

func toPixel*(hsv: Hsv): Pixel =
  ## Converts from HSV to Pixel
  ## HSV values are between 0.0 and 1.0
  let s = hsv.s
  let v = hsv.v
  if s <= 0.0:
    return constructPixel(v, v, v)

  let h = hsv.h

  let i = int(h * 6.0f)
  let f = h * 6.0f - float32(i)
  let p = v * (1.0f - s)
  let q = v * (1.0f - f * s)
  let t = v * (1.0f - (1.0f - f) * s)

  case i mod 6:
    of 0: return constructPixel(v, t, p)
    of 1: return constructPixel(q, v, p)
    of 2: return constructPixel(p, v, t)
    of 3: return constructPixel(p, q, v)
    of 4: return constructPixel(t, p, v)
    of 5: return constructPixel(v, p, q)
    else: return constructPixel(0, 0, 0)

const SPEED = 50
const BRIGHTNESS = 0.2
const SPREAD = 20

const numPixels = 8

proc setPixel(cmd: var openarray[uint8]; index: int; pixel: Pixel) =
  cmd[4 + index * 4] = 0b11100000 or pixel.brightness
  cmd[4 + index * 4 + 1] = pixel.b
  cmd[4 + index * 4 + 2] = pixel.g
  cmd[4 + index * 4 + 3] = pixel.r

proc blinkt() =
  var spiConfig = SpiConfig(
    mode: SPI_MODE_0,
    bits_per_word: 8,
    speed: 10_000_000
  )

  let spidevName = execCmdEx("echo /sys/devices/platform/blinkt/spi_master/*/spi*/spidev/spidev*").output.strip().lastPathPart

  if spidevName == "spidev*":
    echo "spidev for blinkt was not found"
    return

  echo "connecting to spi device " & spidevName

  var spi = spiOpen("/dev" / spidevName, spiConfig)

  echo spiConfig

  if spi.fd < 0:
    echo "error opening spi device: ", spi.fd
    return

  # blinkt has 8 leds
  var cmd = [
    uint8 0x00,0x00,0x00,0x00,
    0xe0,0x00,0x00,0x00,
    0xe0,0x00,0x00,0x00,
    0xe0,0x00,0x00,0x00,
    0xe0,0x00,0x00,0x00,
    0xe0,0x00,0x00,0x00,
    0xe0,0x00,0x00,0x00,
    0xe0,0x00,0x00,0x00,
    0xe0,0x00,0x00,0x00,
    0x00,0x00,0x00,0x00,
    0x00
  ]

  var transfers = [SpiIocTransfer(
    tx_buf: cast[uint64](cmd[0].addr),
    length: cmd.len.uint32
  )]

  while true:
    # rainbow
    for i in 0..<numPixels:
      let h = ((getTime().toUnixFloat() * SPEED + (i.float * SPREAD)) mod 360) / 360.0
      let p = Hsv(h: h, s: 1.0, v: BRIGHTNESS).toPixel()
      setPixel(cmd, i, p)

    echo "spi write: ", cmd

    # this is really fast!
    let ret = spi.transfer(transfers)
    if ret < 0:
      echo "spi write failed"
      break

    sleep(1000 div 200)

blinkt()
