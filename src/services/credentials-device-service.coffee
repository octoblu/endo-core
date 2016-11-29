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

  authorizedFind: ({authorizedUuid, credentialsDeviceUuid}, callback) =>
    authorizedKey = @encryption.sign(authorizedUuid)
    @meshblu.search {uuid: credentialsDeviceUuid, 'endo.authorizedKey': authorizedKey}, {}, (error, devices) =>
      return callback(error) if error?
      device = _.first devices

      return callback @_userError('credentials device not found', 404) unless device?.endo?.encrypted?
      return callback @_userError('credentials device not found', 404) unless @_isSignedCorrectly device

      options =
        uuid: credentialsDeviceUuid
        encrypted: device.endo.encrypted
      return @_getCredentialsDevice options, callback

  getEndoByUuid: (uuid, callback) =>
    @meshblu.device uuid, as: uuid, (error, device) =>
      if error?
        return @_updateDiscoverAsPermissionsAndGetEndo uuid, callback if error.code == 403
        return callback error
      return callback @_userError 'invalid credentials device', 400 unless @_isSignedCorrectly device
      return callback null, device.endo

  _updateDiscoverAsPermissionsAndGetEndo: (uuid, callback) =>
    update = '$addToSet': 'meshblu.whitelists.discover.as': {@uuid}
    @meshblu.updateDangerously uuid, update, (error) =>
      return callback error if error?
      @getEndoByUuid uuid, callback

  getCredentialsTokenFromEndo: ({encrypted}) =>
     @encryption.decrypt(encrypted)?.secrets?.credentialsDeviceToken

  findOrCreate: (resourceOwnerID, callback) =>
    @_findOrCreate resourceOwnerID, (error, device) =>
      return callback error if error?
      @_getCredentialsDevice device, callback

  _findOrCreate: (resourceOwnerID, callback) =>
    return callback new Error('resourceOwnerID is required') unless resourceOwnerID?
    idKey = @encryption.sign(resourceOwnerID)

    @meshblu.search 'endo.idKey': idKey, {}, (error, devices) =>
      return callback error if error?
      devices = _.filter devices, @_isSignedCorrectly
      return callback null, _.first devices unless _.isEmpty devices
      record = credentialsDeviceCreateGenerator {serviceUuid: @uuid}
      @meshblu.register record, (error, device) =>
        return callback error if error?
        @_subscribeToCredentialsMessagesReceived device.uuid, (error) =>
          return callback error, device

  _subscribeToCredentialsMessagesReceived: (credentialsUuid, callback) =>
    subscription = {subscriberUuid: @uuid, emitterUuid: credentialsUuid, type: 'message.received'}
    @meshblu.createSubscription subscription, callback

  _getCredentialsDevice: ({uuid, encrypted}, callback) =>
    @meshblu.generateAndStoreToken uuid, (error, {token}={}) =>
      return callback new Error("Failed to access credentials device") if error?
      meshbluConfig = _.defaults {uuid, token}, @meshbluConfig
      serviceUuid = @uuid
      return callback null, new CredentialsDevice {
        @deviceType
        @imageUrl
        meshbluConfig
        encrypted
        @serviceUrl
        serviceUuid
      }

  _isSignedCorrectly: ({endo, endoSignature, uuid}={}) =>
    return false unless endo?.encrypted?
    return false unless endo?.credentialsDeviceUuid == uuid
    endo = _.cloneDeep endo
    try
      endo.encrypted = @encryption.decrypt endo?.encrypted
    catch error
      console.error error.stack
      return false

    return @encryption.verify endo, endoSignature

  _userError: (message, code) =>
    error = new Error message
    error.code = code if code?
    return error

module.exports = CredentialsDeviceService
