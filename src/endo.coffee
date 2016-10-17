_                        = require 'lodash'
MeshbluHTTP              = require 'meshblu-http'

CredentialsDeviceService = require './services/credentials-device-service'
MessagesService          = require './services/messages-service'
MessageRouter            = require './models/message-router'

Server                   = require './server'
FirehoseMessageProcessor = require './firehose-message-processor'

class Endo
  constructor: (options) ->
    {
      @apiStrategy
      @appOctobluHost
      @deviceType
      @disableLogging
      @logFn
      @firehoseMeshbluConfig
      @meshbluConfig
      @meshbluPublicKeyUri
      @messageHandler
      @octobluStrategy
      @port
      @serviceUrl
      @skipExpress
      @skipRedirectAfterApiAuth
      @staticSchemasPath
      @userDeviceManagerUrl
      @useFirehose
    } = options

    throw new Error('messageHandler is required') unless @messageHandler?
    throw new Error('deviceType is required') unless @deviceType?
    throw new Error('serviceUrl is required') unless @serviceUrl?

  address: =>
    @server?.address()

  run: (callback) =>
    callback = _.after callback, 2 if @useFirehose && !@skipExpress
    meshblu = new MeshbluHTTP @meshbluConfig
    meshblu.whoami (error, device) =>
      throw new Error('Could not authenticate with meshblu!') if error?

      {imageUrl} = device.options ? {}
      credentialsDeviceService  = new CredentialsDeviceService {@meshbluConfig, @serviceUrl, @deviceType, imageUrl}
      messagesService           = new MessagesService {@meshbluConfig, @messageHandler}
      messageRouter             = new MessageRouter {@meshbluConfig, messagesService, credentialsDeviceService}

      unless @skipExpress
        @server = new Server {
          @apiStrategy
          @appOctobluHost
          credentialsDeviceService
          @disableLogging
          @logFn
          @meshbluConfig
          @meshbluPublicKeyUri
          messagesService
          messageRouter
          @octobluStrategy
          @port
          @serviceUrl
          @skipRedirectAfterApiAuth
          @staticSchemasPath
          @userDeviceManagerUrl
        }
        @server.run callback

      if @useFirehose
        @firehoseMeshbluConfig ?= @meshbluConfig
        @firehose = new FirehoseMessageProcessor {meshbluConfig: @firehoseMeshbluConfig, messageRouter}
        @firehose.run callback

  stop: (callback) =>
    callback = _.after callback, 2 if @useFirehose && !@skipExpress
    @server?.stop callback
    @firehose?.stop callback

module.exports = Endo
