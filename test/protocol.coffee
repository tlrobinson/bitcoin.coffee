{ PInteger } = require "../src/protocol"

INTEGER_TEST_CASES = [
  [{ length: 1 },                    -1, [0xFF]]
  [{ length: 1, u: true },            0, [0x00]]
  [{ length: 2, u: true },            1, [0x00, 0x01]]
  [{ length: 2, u: true, le: true },  1, [0x01, 0x00]]
]

describe "PInteger", ->
  describe '#serialize()', ->

    INTEGER_TEST_CASES.forEach (c) ->
      [options, num, bytes] = c
      buf = new Buffer(bytes)
      it "should serialize #{num} with options #{JSON.stringify(options)} to #{bytes}", ->
        actual = new PInteger(options).serialize(num)
        assert.bufferEqual actual, buf

  describe '#deserialize()', ->
    INTEGER_TEST_CASES.forEach (c) ->
      [options, num, bytes] = c
      buf = new Buffer(bytes)
      it "should deserialize #{bytes} with options #{JSON.stringify(options)} to #{num}", ->
        actual = new PInteger(options).deserialize(buf)
        assert.equal actual, num
