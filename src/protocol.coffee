
class Protocol
  constructor: (options = {}) ->
    @options = options
  getLength: (object) ->
    @_getLength(object)
  serialize: (object) ->
    length = @_getLength(object)
    buffer = new Buffer(length)
    @_serialize(object, buffer, 0)
    buffer
  deserialize: (buffer) ->
    @_deserialize(buffer, 0, buffer.length)

class PInteger extends Protocol
  _getLength: (object) ->
    @options.length or 1
  _serialize: (object, buffer, offset) ->
    length = @_getLength()
    if length is 8
      [lower, upper] = Number64.unpack(object)
      [upper, lower] = [lower, upper] unless @options.le
      name = "write" + @_getTypeName(4)
      buffer[name](lower, offset)
      buffer[name](upper, offset + 4)
    else
      name = "write" + @_getTypeName(length)
      buffer[name](object, offset)
    length
  _deserialize: (buffer, offset, len) ->
    length = @_getLength()
    buffer["read" + @_getTypeName(length)](offset)
  _getTypeName: (length) ->
    unsigned = if @options.u then "U" else ""
    bits = length * 8
    byteOrder = if length is 1 then "" else if @options.le then "LE" else "BE"
    "#{unsigned}Int#{bits}#{byteOrder}"

class PString extends Protocol
  _getLength: (object) ->
    if @options.length?
      @options.length
    else
      Buffer.byteLength(object, @options.encoding)
  _serialize: (object, buffer, offset) ->
    written = buffer.write(object, offset, @options.length, @options.encoding)
    if @options.pad?
      buffer.fill(@options.pad, offset + written, offset + @options.length)
      written = @options.length
    written

class PBuffer extends Protocol
  _getLength: (object) ->
    if @options.length?
      @options.length
    else
      object.length
  _serialize: (object, buffer, offset) ->
    length = @_getLength(object)
    return 0 if length is 0
    if Array.isArray(object)
      for b, i in object
        buffer[offset + i] = b
    else
      object.copy(buffer, offset, 0, length)
    length

class PRecord extends Protocol
  _getLength: (object, parentContext = null) ->
    context = object._context = object._context or new SerializationContext(@, object, parentContext)
    length = 0
    for name of @spec
      length += context.getLength(name)
    length
  _serialize: (object, buffer, offset, parentContext = null) ->
    context = object._context = object._context or new SerializationContext(@, object, parentContext)
    context.buffer = buffer
    context.offset = offset
    length = 0
    for name of @spec
      length += context.serializeToBuffer(name)
    length

memoize = (key, fn) ->
  (name) ->
    cache = @cache[key]
    if name of cache
      cache[name]
    else
      cache[name] = fn.apply(@, arguments)

class SerializationContext
  constructor: (protocol, object, parent = null) ->
    @protocol = protocol
    @object = object
    @parent = parent

    @buffer = null
    @offset = null
    @isSerialized = {}

    @cache =
      value: {}
      protocol: {}
      serialized: {}
      length: {}
      offset: {}

  getProtocol: memoize "protocol", (name) ->
    if fn = @protocol.spec[name].options?.protocol
      fn.call(@, @object[name], @object)
    else
      @protocol.spec[name]

  getValue: memoize "value", (name) ->
    if fn = @protocol.spec[name].options?.value
      fn.call(@, @object[name], @object)
    else
      @object[name]

  getLength: memoize "length", (name) ->
    protocol = @getProtocol(name)
    if protocol?
      protocol._getLength(@getValue(name), @)
    else
      0

  getOffset: memoize "offset", (name) ->
    offset = 0
    for other of @protocol.spec
      break if name is other
      offset += @getLength(other)
    offset

  getSerialized: memoize "serialized", (name) ->
    protocol = @getProtocol(name)
    if protocol?
      protocol.serialize(@getValue(name))
    else
      null

  # TODO: Refactor this
  serializeToBuffer: (name) ->
    cache = @cache.serialized
    return if @isSerialized[name]
    @isSerialized[name] = true
    offset = @getOffset(name)
    totalOffset = @offset + offset
    if name of cache
      length = cache[name].copy(@buffer, totalOffset)
    else
      protocol = @getProtocol(name)
      if protocol?
        value = @getValue(name)
        length = protocol._serialize(value, @buffer, totalOffset, @)
      else
        length = 0
      cache[name] = @buffer.slice(totalOffset, totalOffset + length)
    assert.equal length, @getLength(name)
    length

class Number64
  constructor: (lower, upper = 0) ->
    @lower = lower
    @upper = upper
  @unpack: (num) ->
    if typeof num is "number"
      [num % 0x100000000, Math.floor(num / 0x100000000)]
    else if num.lower? and num.upper?
      [num.lower, num.upper]
    else if Array.isArray(num)
      num
    else
      throw new Error("Invalid Number64")

module.exports = { Protocol, PInteger, PString, PBuffer, PRecord, Number64 }
