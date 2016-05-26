_           = require 'lodash'
MeshbluHTTP = require 'meshblu-http'
Encryption  = require 'meshblu-encryption'

credentialsDeviceUpdateGenerator = require '../config-generators/credentials-device-update-config-generator'
userDeviceConfigGenerator = require '../config-generators/user-device-config-generator'

class CredentialsDevice
  constructor: ({@deviceType, @imageUrl, meshbluConfig, @resourceOwnerName, @serviceUrl, @serviceUuid}) ->
    throw new Error('deviceType is required') unless @deviceType?
    throw new Error('serviceUuid is required') unless @serviceUuid?
    {@uuid, @privateKey} = meshbluConfig

    @encryption = Encryption.fromJustGuess @privateKey
    @meshblu    = new MeshbluHTTP meshbluConfig

  createUserDevice: ({authorizedUuid}, callback) =>
    userDeviceConfig = userDeviceConfigGenerator
      authorizedUuid: authorizedUuid
      credentialsUuid: @uuid
      deviceType: @deviceType
      imageUrl: @imageUrl
      resourceOwnerName: @resourceOwnerName

    @meshblu.register userDeviceConfig, (error, userDevice) =>
      return callback error if error?

      subscription = {subscriberUuid: @uuid, emitterUuid: userDevice.uuid, type: 'message.received'}
      @meshblu.createSubscription subscription, (error) =>
        return callback error if error?
        return callback null, userDevice

  deleteUserDeviceSubscription: ({userDeviceUuid}, callback) =>
    return callback @_userError 'Cannot remove the credentials subscription to itself', 403 if userDeviceUuid == @uuid
    subscription =
      emitterUuid: userDeviceUuid
      subscriberUuid: @uuid
      type: 'message.received'

    @meshblu.deleteSubscription subscription, (error, ignored) =>
      callback error

  getPublicDevice: (callback) =>
    @meshblu.device @serviceUuid, (error, device) =>
      return callback error if error?
      return callback null, device.options

  getUserDevices: (callback) =>
    @meshblu.subscriptions @uuid, (error, subscriptions) =>
      return callback error if error?
      return callback null, @_userDevicesFromSubscriptions subscriptions

  getUuid: => @uuid

  update: ({authorizedUuid, name, id, credentials}, callback) =>
    credentialsDeviceUuid = @uuid

    {endo, endoSignature} = @_getSignedUpdate {authorizedUuid, id, name, credentials, credentialsDeviceUuid}
    endo.encrypted = @encryption.encrypt endo.encrypted

    update = credentialsDeviceUpdateGenerator {endo, endoSignature, @serviceUrl}
    @meshblu.updateDangerously @uuid, update, (error) =>
      return callback error if error?
      @_subscribeToOwnMessagesReceived callback

  _getSignedUpdate: ({authorizedUuid, id, name, credentials}) =>
    endo = {
      authorizedKey: @encryption.sign(authorizedUuid).toString 'base64'
      credentialsDeviceUuid: @uuid
      version: '1.0.0'
      encrypted:
        id: id
        name: name
        secrets:
          credentials: credentials
    }
    endoSignature = @encryption.sign endo
    return {endo, endoSignature}

  _subscribeToOwnMessagesReceived: (callback) =>
    subscription = {subscriberUuid: @uuid, emitterUuid: @uuid, type: 'message.received'}
    @meshblu.createSubscription subscription, (error, ignored) =>
      return callback error if error?
      return callback()

  _userDevicesFromSubscriptions: (subscriptions) =>
    _(subscriptions)
      .filter type: 'message.received'
      .reject emitterUuid: @uuid
      .map ({emitterUuid}) => {uuid: emitterUuid}
      .value()

  _userError: (message, code) =>
    error = new Error message
    error.code = code if code?
    return error

module.exports = CredentialsDevice
