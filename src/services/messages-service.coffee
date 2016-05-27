fs          = require 'fs'
{Validator} = require 'jsonschema'
_           = require 'lodash'
Encryption  = require 'meshblu-encryption'
MeshbluHTTP = require 'meshblu-http'
path        = require 'path'

# ENDO_MESSAGE_INVALID   = 'Message does not match endo schema'
MISSING_METADATA         = 'Message is missing required property "metadata"'
# JOB_TYPE_UNSUPPORTED   = 'That jobType is not supported'
# JOB_TYPE_UNIMPLEMENTED = 'That jobType has not yet been implemented'
# MESSAGE_DATA_INVALID   = 'Message data does not match schema for jobType'
MISSING_ROUTE_HEADER   = 'Missing x-meshblu-route header in request'

class MessagesService
  constructor: ({@messageHandler}) ->
    throw new Error 'messageHandler is required' unless @messageHandler?

    @endoMessageSchema = @_getEndoMessageSchemaSync()
    @validator = new Validator

  reply: ({auth, route, response}, callback) =>
    return callback @_userError(MISSING_ROUTE_HEADER, 422) if _.isEmpty route

    firstHop       = _.first JSON.parse route
    senderUuid     = firstHop.from
    userDeviceUuid = firstHop.to

    message =
      devices:  [senderUuid]
      metadata: response.metadata
      data:     response.data

    meshblu = new MeshbluHTTP auth
    meshblu.message message, as: userDeviceUuid, callback

  replyWithError: ({auth, error, route}, callback) =>
    return callback @_userError(MISSING_ROUTE_HEADER, 422) if _.isEmpty route
    firstHop       = _.first JSON.parse route
    senderUuid     = firstHop.from
    userDeviceUuid = firstHop.to

    message =
      devices: [senderUuid]
      metadata:
        code: error.code ? 500
        error:
          message: error.message

    meshblu = new MeshbluHTTP auth
    meshblu.message message, as: userDeviceUuid, callback

  schema: (callback) =>
    @messageHandler.schema callback

  send: ({auth, endo, message}, callback) =>
    return callback @_userError(MISSING_METADATA, 422) unless message?.metadata?
    {data, metadata} = message

    encryption = Encryption.fromJustGuess auth.privateKey
    encrypted  = encryption.decrypt endo.encrypted
    @messageHandler.onMessage {data, encrypted, metadata}, callback

  _getEndoMessageSchemaSync: =>
    filepath = path.join __dirname, '../../endo-message-schema.json'
    JSON.parse fs.readFileSync(filepath, 'utf8')

  _userError: (message, code) =>
    error = new Error message
    error.code = code if code?
    return error

module.exports = MessagesService
