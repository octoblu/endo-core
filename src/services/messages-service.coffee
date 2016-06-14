{Validator} = require 'jsonschema'
_           = require 'lodash'
Encryption  = require 'meshblu-encryption'
MeshbluHTTP = require 'meshblu-http'

debug = require('debug')('endo-core:messages-service')

MISSING_METADATA     = 'Message is missing required property "metadata"'
MISSING_ROUTE_HEADER = 'Missing x-meshblu-route header in request'

class MessagesService
  constructor: ({@messageHandler}) ->
    throw new Error 'messageHandler is required' unless @messageHandler?
    @validator = new Validator

  formSchema: (callback) =>
    @messageHandler.formSchema callback

  messageSchema: (callback) =>
    @messageHandler.messageSchema callback

  reply: ({auth, route, response, respondTo}, callback) =>
    return callback @_userError(MISSING_ROUTE_HEADER, 422) if _.isEmpty route

    firstHop       = _.first JSON.parse route
    senderUuid     = firstHop.from
    userDeviceUuid = firstHop.to
    metadata       = _.assign {to: respondTo}, response.metadata

    message =
      devices:  [senderUuid]
      metadata: metadata
      data:     response.data

    meshblu = new MeshbluHTTP auth
    meshblu.message message, as: userDeviceUuid, callback

  replyWithError: ({auth, error, route, respondTo}, callback) =>
    return callback @_userError(MISSING_ROUTE_HEADER, 422) if _.isEmpty route
    firstHop       = _.first JSON.parse route
    senderUuid     = firstHop.from
    userDeviceUuid = firstHop.to

    message =
      devices: [senderUuid]
      metadata:
        code: error.code ? 500
        to: respondTo
        error:
          message: error.message

    meshblu = new MeshbluHTTP auth
    meshblu.message message, as: userDeviceUuid, callback

  responseSchema: (callback) =>
    @messageHandler.responseSchema callback

  send: ({auth, endo, message}, callback) =>
    return callback @_userError(MISSING_METADATA, 422) unless message?.metadata?
    {data, metadata} = message
    debug 'send', JSON.stringify({data,metadata})

    encryption = Encryption.fromJustGuess auth.privateKey
    encrypted  = encryption.decrypt endo.encrypted
    @messageHandler.onMessage {data, encrypted, metadata}, callback

  _userError: (message, code) =>
    error = new Error message
    error.code = code if code?
    return error

module.exports = MessagesService
