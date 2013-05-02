
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

class PInteger extends Protocol
  _getLength: (object) ->
    @options.length or 1
  _getTypeName: (length) ->
    u = if @options.u then "U" else ""
    l = length * 8
    o = if length is 1 then "" else if @options.le then "LE" else "BE"
    "#{u}Int#{l}#{o}"
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

class SerializationContext
  constructor: (protocol, object, parent = null) ->
    @protocol = protocol
    @object = object
    @parent = parent
    @cache =
      value: {}
      protocol: {}
      serialized: {}
      length: {}
      offset: {}
    @buffer = null
    @offset = null
    @isSerialized = {}
  getProtocol: (name) ->
    cache = @cache.protocol
    unless name of cache
      if fn = @protocol.spec[name].options?.protocol
        cache[name] = fn.call(@, @object[name], @object)
      else
        cache[name] = @protocol.spec[name]
    cache[name]
  getValue: (name) ->
    cache = @cache.value
    unless name of cache
      if fn = @protocol.spec[name].options?.value
        cache[name] = fn.call(@, @object[name], @object)
      else
        cache[name] = @object[name]
    cache[name]
  getLength: (name) ->
    cache = @cache.length
    unless name of cache
      protocol = @getProtocol(name)
      cache[name] = protocol?._getLength(@getValue(name), @) or 0
    cache[name]
  getOffset: (name) ->
    cache = @cache.offset
    unless name of cache
      offset = 0
      for other of @protocol.spec
        break if name is other
        offset += @getLength(other)
      cache[name] = offset
    cache[name]
  getSerialized: (name) ->
    cache = @cache.serialized
    unless name of cache
      value = @getValue(name)
      cache[name] = @getProtocol(name)?.serialize(value)
    cache[name]

  serializeToBuffer: (name) ->
    cache = @cache.serialized
    return if @isSerialized[name]
    @isSerialized[name] = true
    offset = @getOffset(name)
    totalOffset = @offset + offset
    if name of cache
      length = cache[name].copy(@buffer, totalOffset)
    else
      value = @getValue(name)
      length = @getProtocol(name)?._serialize(value, @buffer, totalOffset, @) or 0
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
