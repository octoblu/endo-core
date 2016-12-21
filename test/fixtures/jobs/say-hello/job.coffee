http          = require 'http'

class SayHello
  constructor: ->

  do: (message, callback) =>
    callback null, {
      metadata:
        code: 204
        status: http.STATUS_CODES[204]
    }

module.exports = SayHello
