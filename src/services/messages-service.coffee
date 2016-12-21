_           = require 'lodash'
moment      = require 'moment'

{Validator} = require 'jsonschema'
Encryption  = require 'meshblu-encryption'
MeshbluHTTP = require 'meshblu-http'

MISSING_METADATA     = 'Message is missing required property "metadata"'

class MessagesService
  constructor: ({@messageHandler, @meshbluConfig}) ->
    throw new Error 'messageHandler is required' unless @messageHandler?
    @validator = new Validator

  formSchema: (callback) =>
    @messageHandler.formSchema callback

  messageSchema: (callback) =>
    @messageHandler.messageSchema callback

  reply: ({auth, senderUuid, userDeviceUuid, response, respondTo}, callback) =>
    metadata       = _.assign {to: respondTo}, response.metadata

    message =
      devices:  [senderUuid]
      metadata: metadata
      data:     response.data

    meshblu = new MeshbluHTTP _.defaults auth, @meshbluConfig
    meshblu.message message, as: userDeviceUuid, callback

  replyWithError: ({auth, senderUuid, userDeviceUuid, error, respondTo}, callback) =>
    message =
      devices: [senderUuid]
      metadata:
        code: error.code ? 500
        to: respondTo
        error:
          message: error.message

    meshblu = new MeshbluHTTP _.defaults auth, @meshbluConfig
    meshblu.message message, as: userDeviceUuid, (newError) =>
      return callback newError if newError?
      @_updateStatusDeviceWithError {auth, senderUuid, userDeviceUuid, error, respondTo}, callback

  _updateStatusDeviceWithError: ({auth, senderUuid, userDeviceUuid, error, respondTo}, callback) =>
    meshblu = new MeshbluHTTP _.defaults auth, @meshbluConfig
    meshblu.device userDeviceUuid, (newError, {statusDevice}={}) =>
      return callback() if newError?
      return callback() unless statusDevice?
      update =
        $push:
          errors:
            $each: [
              senderUuid: senderUuid
              date: moment.utc().format()
              metadata:
                to: respondTo
              code: error.code ? 500
              message: error.message
            ]
            $slice: -99
      meshblu.updateDangerously statusDevice, update, as: userDeviceUuid, callback

  responseSchema: (callback) =>
    @messageHandler.responseSchema callback

  send: ({endo, message}, callback) =>
    return callback @_userError(MISSING_METADATA, 422) unless message?.metadata?
    {data, metadata} = message
    encryption = Encryption.fromJustGuess @meshbluConfig.privateKey
    encrypted  = encryption.decrypt endo.encrypted
    encrypted.secrets = _.omit encrypted.secrets, 'credentialsDeviceToken'
    @messageHandler.onMessage {data, encrypted, metadata}, callback

  _userError: (message, code) =>
    error = new Error message
    error.code = code if code?
    return error

module.exports = MessagesService
