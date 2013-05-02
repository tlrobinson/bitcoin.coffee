{ Protocol, PInteger, PString, PBuffer, PRecord, Number64 } = require "./protocol"

crypto = require "crypto"
sha256 = (buffer) ->
  crypto.createHash("sha256").update(buffer).digest()

# Inventory Vector
#   4   type          uint32_t  Identifies the object type linked to this inventory
#   32  hash          char[32]  Hash of the object

# Block Headers
#   4   version       uint32_t  Block version information, based upon the software version creating this block
#   32  prev_block    char[32]  The hash value of the previous block this particular block references
#   32  merkle_root   char[32]  The reference to a Merkle tree collection which is a hash of all transactions related to this block
#   4   timestamp     uint32_t  A timestamp recording when this block was created (Limited to 2106!)
#   4   bits          uint32_t  The calculated difficulty target being used for this block
#   4   nonce         uint32_t  The nonce used to generate this block… to allow variations of the header and compute different hashes
#   1   txn_count     uint8_t   Number of transaction entries, this value is always 0

# Variable Length Integer
#   < 0xfd          1   uint8_t
#   <= 0xffff       3   0xfd followed by the length as uint16_t
#   <= 0xffffffff   5   0xfe followed by the length as uint32_t
#   -               9   0xff followed by the length as uint64_t
class VarInt extends PRecord
  spec:
    _sentinal: new PInteger(length: 1, u: true, value: (value, object) ->
      [lower, upper] = Number64.unpack(object)
      if upper > 0
        0xFF
      else if lower < 0xFD
        lower
      else if lower <= 0xFFFF
        0xFD
      else if lower <= 0xFFFFFFFF
        0xFE
      else
        throw new Error("Invalid VarInt #{upper} #{lower}")
    )
    value: new Protocol(value: ((value, object) -> object), protocol: (value, object) ->
      [lower, upper] = Number64.unpack(object)
      if upper > 0
        new PInteger(length: 8, u: true, le: true)
      else if lower < 0xFD
        null
      else if lower <= 0xFFFF
        new PInteger(length: 2, u: true, le: true)
      else if lower <= 0xFFFFFFFF
        new PInteger(length: 4, u: true, le: true)
      else
        throw new Error("Invalid VarInt #{upper} #{lower}")
    )

# Variable Length String
#   ?   length        var_int   Length of the string
#   ?   string        char[]    The string itself (can be empty)
class VarStr extends PRecord
  spec:
    length: new VarInt(value: -> @getLength("string"))
    string: new PString(value: (value, object) -> object)


# Network Address
#   4   time          uint32    the Time (version >= 31402)
#   8   services      uint64_t  same service(s) listed in version
#   16  IPv6/4        char[16]  IPv6 address. Network byte order. The original client only supports IPv4 and only reads the last 4 bytes to get the IPv4 address. However, the IPv4 address is written into the message as a 16 byte IPv4-mapped IPv6 address (12 bytes 00 00 00 00 00 00 00 00 00 00 FF FF, followed by the 4 bytes of the IPv4 address).
#   2   port          uint16_t  port number, network byte order
class NetAddr extends PRecord
  spec:
    # time: new PInteger(length: 4, u: true, le: true)
    services: new PInteger(length: 8, u: true, le: true)
    host: new PBuffer(length: 16, value: (value) ->
      if value.length is 4
        [0,0,0,0,0,0,0,0,0,0,0xFF,0xFF].concat(value)
      else if value.length is 16
        value
      else
        throw new Error("Invalid NetAddr")
    )
    port: new PInteger(length: 2, u: true, le: false)

# Message
#   4   magic         uint32_t  Magic value indicating message origin network, and used to seek to next message when stream state is unknown
#   12  command       char[12]  ASCII string identifying the packet content, NULL padded (non-NULL padding results in packet rejected)
#   4   length        uint32_t  Length of payload in number of bytes
#   4   checksum      uint32_t  First 4 bytes of sha256(sha256(payload))
#   ?   payload       uchar[]   The actual data
class Message extends PRecord
  spec:
    magic: new PInteger(length: 4, u: true, le: true)
    command: new PString(length: 12, pad: 0x00)
    length: new PInteger(length: 4, u: true, le: true, value: -> @getLength("payload"))
    checksum: new PBuffer(length: 4, value: ->
      payload = @getSerialized("payload")
      sha256(sha256(payload))[0..4]
    )
    payload: new Protocol(protocol: ->
      command = @getValue("command")
      MESSAGE_PROTOCOLS[command]
    )

# Message Types

# Version
#   4   version       int32_t   Identifies protocol version being used by the node
#   8   services      uint64_t  bitfield of features to be enabled for this connection
#   8   timestamp     int64_t   standard UNIX timestamp in seconds
#   26  addr_recv     net_addr  The network address of the node receiving this message
# version >= 106
#   26  addr_from     net_addr  The network address of the node emitting this message
#   8   nonce         uint64_t  Node random nonce, randomly generated every time a version packet is sent. This nonce is used to detect connections to self.
#   ?   user_agent    var_str   User Agent (0x00 if string is 0 bytes long)
#   4   start_height  int32_t   The last block received by the emitting node
# version >= 70001
#   1   relay         bool      Whether the remote peer should announce relayed transactions or not, see BIP 0037, since version >= 70001
class Version extends PRecord
  spec:
    version: new PInteger(length: 4, le: true)
    services: new PInteger(length: 8, u: true, le: true)
    timestamp: new PInteger(length: 8, le: true)
    addr_recv: new NetAddr()
    addr_from: new NetAddr()
    nonce: new PBuffer(length: 8)
    user_agent: new VarStr()
    start_height: new PInteger(length: 4, le: true)

MESSAGE_PROTOCOLS = {}
MESSAGE_PROTOCOLS["version"] = new Version()
MESSAGE_PROTOCOLS["verack"] = new PBuffer(length: 0)

module.exports = { VarInt, VarStr, NetAddr, Message }
