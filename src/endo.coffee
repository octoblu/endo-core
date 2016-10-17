CredentialsDeviceService = require './services/credentials-device-service'
MessagesService          = require './services/messages-service'
MessageRouter            = require './models/message-router'

Server                   = require './server'
FirehoseMessageProcessor = require './firehose-message-processor'

_ = require 'lodash'

class Endo
  constructor: (@options)->
    {@useFirehose=false, @skipExpress=false} = @options

  address: =>
    @server?.address()

  run: (callback) =>
    callback = _.after callback, 2 if @useFirehose && !@skipExpress
    unless @skipExpress
      @server = new Server @options
      @server.run callback

    if @useFirehose
      @firehose = new FirehoseMessageProcessor @options
      @firehose.run callback

  stop: (callback) =>
    callback = _.after callback, 2 if @useFirehose && !@skipExpress
    @server?.stop callback
    @firehose?.stop callback

module.exports = Endo
