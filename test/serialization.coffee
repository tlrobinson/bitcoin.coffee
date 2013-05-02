{ Message, NetAddr, VarInt, VarStr } = require "../src/serialization"

VAR_INT_CASES = [
  # 1 byte
  [0x00,        [0x00]]
  [0x01,        [0x01]]
  [0xfc,        [0xfc]]
  # 3 byte
  [0xfd,        [0xfd, 0xfd, 0x00]]
  [0xfe,        [0xfd, 0xfe, 0x00]]
  [0xfffe,      [0xfd, 0xfe, 0xff]]
  [0xffff,      [0xfd, 0xff, 0xff]]
  # 5 byte
  [0x10000,     [0xfe, 0x00, 0x00, 0x01, 0x00]]
  [0xfffffffe,  [0xfe, 0xfe, 0xff, 0xff, 0xff]]
  [0xffffffff,  [0xfe, 0xff, 0xff, 0xff, 0xff]]
  # 9 byte
  [0x100000000,              [0xff, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00]]
  [[0x00000000, 0x00000001], [0xff, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00]]
  [[0xffffffff, 0xffffffff], [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]]
]

describe "VarInt", ->
  describe '#serialize()', ->
  for c in VAR_INT_CASES
    do (c) ->
      it "should serialize #{c[0].toString(16)} correctly", ->
        assert.bufferEqual new VarInt().serialize(c[0]), new Buffer(c[1])

LONG_A_STRING = Array(0xfd+1).join("a")
VAR_STR_CASES = [
  # length 0
  ["",  [0]]
  # length 1
  ["a", [1, 0x61]]
  # length 0xfd
  [LONG_A_STRING, [0xfd, 0xfd, 0x00].concat(LONG_A_STRING.split("").map((l) -> l.charCodeAt(0)))]
]

describe "VarStr", ->
  describe '#serialize()', ->
  for c in VAR_STR_CASES
    do (c) ->
      it "should serialize '#{c[0]}' correctly", ->
        assert.bufferEqual new VarStr().serialize(c[0]), new Buffer(c[1])

describe "NetAddr", ->
  describe '#serialize()', ->
    it "should serialize correctly", ->
      actual = new NetAddr().serialize
        services: 0x01
        host: [10,0,0,1]
        port: 8333
      assert.bufferEqual actual, NET_ADDR_EXAMPLE

describe "Message", ->
  describe '#serialize()', ->

    it "should serialize 'version' (no hash) correctly", ->
      actual = new Message().serialize
        magic: 0xD9B4BEF9
        command: "version"
        payload:
          version: 31900
          services: 0x01
          timestamp: new Date("Mon Dec 20 21:50:14 EST 2010").getTime() / 1000
          addr_recv:
            services: 0x01
            host: [10,0,0,1]
            port: 8333
          addr_from:
            services: 0x01
            host: [10,0,0,2]
            port: 8333
          nonce: new Buffer("DD9D202C3AB45713", "hex")
          user_agent: ""
          start_height: 98645
      assert.bufferEqual actual, VERSION_EXAMPLE_OLD

    it "should serialize 'version' (with hash) correctly", ->
      actual = new Message().serialize
        magic: 0xD9B4BEF9
        command: "version"
        payload:
          version: 60002
          services: 0x01
          timestamp: new Date("Tue Dec 18 10:12:33 PST 2012").getTime() / 1000
          addr_recv:
            services: 0x01
            host: [0,0,0,0]
            port: 0
          addr_from:
            services: 0x01
            host: [0,0,0,0]
            port: 0
          nonce: new Buffer("3B2EB35D8CE61765", "hex")
          user_agent: "/Satoshi:0.7.2/"
          start_height: 212672
      assert.bufferEqual actual, VERSION_EXAMPLE

    it "should serialize 'verack' correctly", ->
      actual = new Message().serialize
        magic: 0xD9B4BEF9
        command: "verack"
      assert.bufferEqual actual, VERACK_EXAMPLE

convertToBuffer = (array) ->
  new Buffer(array.join("").replace(/[^0-9a-f]/ig, ""), "hex")

NET_ADDR_EXAMPLE = convertToBuffer [
  # Network address:
  "01 00 00 00 00 00 00 00                        " #- 1 (NODE_NETWORK: see services listed under version command)
  "00 00 00 00 00 00 00 00 00 00 FF FF 0A 00 00 01" #- IPv6: ::ffff:10.0.0.1 or IPv4: 10.0.0.1
  "20 8D                                          " #- Port 8333
]

VERSION_EXAMPLE_OLD = convertToBuffer [
  # Message header:
  " F9 BE B4 D9                                                                  " #- Main network magic bytes
  " 76 65 72 73 69 6F 6E 00 00 00 00 00                                          " #- "version" command
  " 55 00 00 00                                                                  " #- Payload is 85 bytes long
  "                                                                              " #- No checksum in version message until 20 February 2012. See https://bitcointalk.org/index.php?topic=55852.0
  # Version message:
  " 9C 7C 00 00                                                                  " #- 31900 (version 0.3.19)
  " 01 00 00 00 00 00 00 00                                                      " #- 1 (NODE_NETWORK services)
  " E6 15 10 4D 00 00 00 00                                                      " #- Mon Dec 20 21:50:14 EST 2010
  " 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 FF FF 0A 00 00 01 20 8D" #- Recipient address info - see Network Address
  " 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 FF FF 0A 00 00 02 20 8D" #- Sender address info - see Network Address
  " DD 9D 20 2C 3A B4 57 13                                                      " #- Node random unique ID
  " 00                                                                           " #- "" sub-version string (string is 0 bytes long)
  " 55 81 01 00                                                                  " #- Last block sending node has is block #98645
]

VERSION_EXAMPLE = convertToBuffer [
  # Message Header:
  " F9 BE B4 D9                                                                  " #- Main network magic bytes
  " 76 65 72 73 69 6F 6E 00 00 00 00 00                                          " #- "version" command
  " 64 00 00 00                                                                  " #- Payload is 100 bytes long
  # NOTE: this checksum from the wiki appears to be incorrect
  # " 35 8D 49 32                                                                  " #- payload checksum
  " 3B 64 8D 5A                                                                  " #- payload checksum
  # Version message:
  " 62 EA 00 00                                                                  " #- 60002 (protocol version 60002)
  " 01 00 00 00 00 00 00 00                                                      " #- 1 (NODE_NETWORK services)
  " 11 B2 D0 50 00 00 00 00                                                      " #- Tue Dec 18 10:12:33 PST 2012
  " 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 FF FF 00 00 00 00 00 00" #- Recipient address info - see Network Address
  " 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 FF FF 00 00 00 00 00 00" #- Sender address info - see Network Address
  " 3B 2E B3 5D 8C E6 17 65                                                      " #- Node ID
  " 0F 2F 53 61 74 6F 73 68 69 3A 30 2E 37 2E 32 2F                              " #- "/Satoshi:0.7.2/" sub-version string (string is 15 bytes long)
  " C0 3E 03 00                                                                  " #- Last block sending node has is block #212672
]

VERACK_EXAMPLE = convertToBuffer [
  # Message header:
  "F9 BE B4 D9                         " #- Main network magic bytes
  "76 65 72 61  63 6B 00 00 00 00 00 00" #- "verack" command
  "00 00 00 00                         " #- Payload is 0 bytes long
  "5D F6 E0 E2                         " #- Checksum
]
