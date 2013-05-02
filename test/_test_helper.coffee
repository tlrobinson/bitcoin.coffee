# global.assert = require("chai").assert
global.assert = require("assert")

splitBuffer = (buffer, size) ->
  for i in [0..buffer.length/size]
    buffer.slice(i*size, Math.min(buffer.length, (i+1)*size))

formatBuffer = (buffer) ->
  (for row in splitBuffer(buffer, 8)
    # (for col in splitBuffer(row, 8)
      (for byte in row
        (if byte < 0x10 then "0" else "") + byte.toString(16)
      ).join(" ")
    # ).join("  ")
  ).join(" \n")

global.assert.bufferEqual = (actual, expected) ->
  assert.equal formatBuffer(actual), formatBuffer(expected)
