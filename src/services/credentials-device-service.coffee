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
    @encryption = Encryption.fromJustGuess @meshbluConfig.privateKey

  authorizedFindByUuid: ({authorizedUuid, credentialsDeviceUuid}, callback) =>
    authorizedKey = @encryption.sign(authorizedUuid)
    @meshblu.search {uuid: credentialsDeviceUuid, 'endo.authorizedKey': authorizedKey}, {}, (error, devices) =>
      return callback(error) if error?
      device = _.first devices

      return callback @_userError('credentials device not found', 404) unless device?
      return callback @_userError('credentials device not found', 404) unless @_isSignedCorrectly device

      options =
        uuid: credentialsDeviceUuid
        resourceOwnerName: device.endo.resourceOwnerName

      return @_getCredentialsDevice options, callback

  getEndoByUuid: (uuid, callback) =>
    @meshblu.device uuid, (error, device) =>
      return callback error if error?
      return callback @_userError 'invalid credentials device', 400 unless @_isSignedCorrectly device
      return callback null, device.endo

  findOrCreate: (resourceOwnerID, callback) =>
    @_findOrCreate resourceOwnerID, (error, device) =>
      return callback error if error?
      @_getCredentialsDevice device, callback

  _findOrCreate: (resourceOwnerID, callback) =>
    return callback new Error('resourceOwnerID is required') unless resourceOwnerID?
    authorizedKey = @encryption.sign(resourceOwnerID)

    @meshblu.search 'endo.authorizedKey': authorizedKey, {}, (error, devices) =>
      return callback error if error?
      devices = _.filter devices, @_isSignedCorrectly
      return callback null, _.first devices unless _.isEmpty devices
      record = credentialsDeviceCreateGenerator {serviceUuid: @uuid}
      @meshblu.register record, callback

  _getCredentialsDevice: ({uuid, resourceOwnerName}, callback) =>
    @meshblu.generateAndStoreToken uuid, (error, {token}={}) =>
      return callback new Error("Failed to access credentials device") if error?
      meshbluConfig = _.defaults {uuid, token}, @meshbluConfig
      return callback null, new CredentialsDevice {@deviceType, @imageUrl, meshbluConfig, resourceOwnerName, @serviceUrl}

  _isSignedCorrectly: ({endo, endoSignature, uuid}={}) =>
    return false unless endo?.secrets?
    return false unless endo.credentialsDeviceUuid == uuid
    endo = _.cloneDeep endo
    try
      endo.secrets = @encryption.decrypt endo.secrets
    catch error
      console.error error.stack
      return false

    return @encryption.verify endo, endoSignature

  _userError: (message, code) =>
    error = new Error message
    error.code = code if code?
    return error

module.exports = CredentialsDeviceService
