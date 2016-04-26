_ = require 'lodash'
MeshbluHTTP = require 'meshblu-http'
CredentialsDevice = require '../models/credentials-device'
credentialsDeviceCreateGenerator = require '../config-generators/credentials-device-create-config-generator'
Encryption = require 'meshblu-encryption'

class CredentialsDeviceService
  constructor: ({@deviceType, @imageUrl, @meshbluConfig, @serviceUrl}) ->
    throw new Error('deviceType is required') unless @deviceType?
    @uuid = @meshbluConfig.uuid
    @meshblu = new MeshbluHTTP @meshbluConfig

  authorizedFindByUuid: ({authorizedUuid, credentialsDeviceUuid}, callback) =>
    @meshblu.search {uuid: credentialsDeviceUuid, 'endo.authorizedUuid': authorizedUuid}, {}, (error, devices) =>
      return callback(error) if error?
      return callback @_userError('credentials device not found', 403) if _.isEmpty devices
      options =
        uuid: credentialsDeviceUuid
        resourceOwnerName: _.first(devices).endo.resourceOwnerName

      return @_getCredentialsDevice options, callback

  getEndoByUuid: (uuid, callback) =>
    @meshblu.device uuid, (error, {endo}={}) =>
      return callback error if error?
      return callback null, endo

  findOrCreate: (resourceOwnerID, callback) =>
    @_findOrCreate resourceOwnerID, (error, device) =>
      return callback error if error?
      @_getCredentialsDevice device, callback

  _findOrCreate: (resourceOwnerID, callback) =>
    return callback new Error('resourceOwnerID is required') unless resourceOwnerID?
    encryption = Encryption.fromJustGuess @meshbluConfig.privateKey
    endoKey = encryption.sign(resourceOwnerID).toString 'base64'
    @meshblu.search 'endo.key': endoKey, {}, (error, devices) =>
      return callback error if error?
      return callback null, _.first devices unless _.isEmpty devices
      record = credentialsDeviceCreateGenerator {resourceOwnerID: resourceOwnerID, serviceUuid: @uuid}
      @meshblu.register record, callback

  _getCredentialsDevice: ({uuid, resourceOwnerName}, callback) =>
    @meshblu.generateAndStoreToken uuid, (error, {token}={}) =>
      return callback error if error?
      meshbluConfig = _.defaults {uuid, token}, @meshbluConfig
      return callback null, new CredentialsDevice {@deviceType, @imageUrl, meshbluConfig, resourceOwnerName, @serviceUrl}

  _userError: (message, code) =>
    error = new Error message
    error.code = code if code?
    return error

module.exports = CredentialsDeviceService
