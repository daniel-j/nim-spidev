
import std/posix

{.push header: "linux/spi/spidev.h".}

let SPI_IOC_WR_MODE* {.importc: "SPI_IOC_WR_MODE".}: uint
let SPI_IOC_RD_MODE* {.importc: "SPI_IOC_RD_MODE".}: uint
let SPI_IOC_WR_BITS_PER_WORD* {.importc: "SPI_IOC_WR_BITS_PER_WORD".}: uint
let SPI_IOC_RD_BITS_PER_WORD* {.importc: "SPI_IOC_RD_BITS_PER_WORD".}: uint
let SPI_IOC_WR_MAX_SPEED_HZ* {.importc: "SPI_IOC_WR_MAX_SPEED_HZ".}: uint
let SPI_IOC_RD_MAX_SPEED_HZ* {.importc: "SPI_IOC_RD_MAX_SPEED_HZ".}: uint
let SPI_IOC_WR_MODE32* {.importc: "SPI_IOC_RD_MODE32".}: uint
let SPI_IOC_RD_MODE32* {.importc: "SPI_IOC_RD_MODE32".}: uint

let SPI_MODE_0* {.importc: "SPI_MODE_0".}: uint8
let SPI_MODE_1* {.importc: "SPI_MODE_1".}: uint8
let SPI_MODE_2* {.importc: "SPI_MODE_2".}: uint8
let SPI_MODE_3* {.importc: "SPI_MODE_3".}: uint8

type
  SpiIocTransfer* {.importc: "struct spi_ioc_transfer".} = object
    rx_buf*: uint64
    tx_buf*: uint64
    length* {.importc: "len".}: uint32
    speed_hz*: uint32
    delay_usecs*: uint16
    bits_per_word*: uint8
    cs_change*: uint8
    tx_nbits*: uint8
    rx_nbits*: uint8
    word_delay_usecs*: uint8

proc SPI_IOC_MESSAGE*(count: int): uint {.importc: "SPI_IOC_MESSAGE".}

{.pop.}

type
  Spidev* = object
    fd*: cint

  SpiConfig* = object
    mode*: uint8
    bits_per_word*: uint8
    speed*: uint32

proc `=copy`(dest: var Spidev; source: Spidev) {.error.}
proc `=destroy`*(self: var Spidev) =
  discard posix.close(self.fd)


proc spiOpen*(path: string; config: var SpiConfig): Spidev =
  result.fd = -1

  # Open block device
  let fd = posix.open(path.cstring, O_RDWR)
  if fd < 0:
    return


  # Set SPI_POL and SPI_PHA
  if fd.ioctl(SPI_IOC_WR_MODE, config.mode.addr) < 0:
    discard posix.close(fd)
    return

  if fd.ioctl(SPI_IOC_RD_MODE, config.mode.addr) < 0:
    discard posix.close(fd)
    return

  # Set bits per word
  if fd.ioctl(SPI_IOC_WR_BITS_PER_WORD, config.bits_per_word.addr) < 0:
    discard posix.close(fd)
    return

  if fd.ioctl(SPI_IOC_RD_BITS_PER_WORD, config.bits_per_word.addr) < 0:
    discard posix.close(fd)
    return


  # Set SPI speed
  if fd.ioctl(SPI_IOC_WR_MAX_SPEED_HZ, config.speed.addr) < 0:
    discard posix.close(fd)
    return

  if fd.ioctl(SPI_IOC_RD_MAX_SPEED_HZ, config.speed.addr) < 0:
    discard posix.close(fd)
    return

  # Return file descriptor
  result.fd = fd

proc transfer*(self: Spidev; transfers: var openarray[SpiIocTransfer]): int {.inline.} =
  return self.fd.ioctl(SPI_IOC_MESSAGE(transfers.len), transfers[0].unsafeAddr)

proc transfer*(self: Spidev; txBuffer: openarray[uint8]; rxBuffer: var openarray[uint8]; length: int): int =
  assert(self.fd >= 0)

  var spiMessage = [SpiIocTransfer(
    rx_buf: cast[uint64](rxBuffer[0].addr),
    tx_buf: cast[uint64](txBuffer[0].unsafeAddr),
    length: length.uint32
  )]

  return self.transfer(spiMessage)

proc read*(self: Spidev; rxBuffer: var openarray[uint8]; length: int): int =
  assert(self.fd >= 0)

  var spiMessage = [SpiIocTransfer(
    rx_buf: cast[uint64](rxBuffer[0].addr),
    length: length.uint32
  )]

  return self.transfer(spiMessage)

proc write*(self: Spidev; txBuffer: openarray[uint8]; length: int): int =
  assert(self.fd >= 0)

  var spiMessage = [SpiIocTransfer(
    tx_buf: cast[uint64](txBuffer[0].unsafeAddr),
    length: length.uint32
  )]

  return self.transfer(spiMessage)

