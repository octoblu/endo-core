fs          = require 'fs'
_           = require 'lodash'
MeshbluHTTP = require 'meshblu-http'
Encryption  = require 'meshblu-encryption'
path        = require 'path'

credentialsDeviceUpdateGenerator = require '../config-generators/credentials-device-update-config-generator'
userDeviceConfigGenerator = require '../config-generators/user-device-config-generator'

class CredentialsDevice
  constructor: ({@deviceType, @imageUrl, @serviceUrl, meshbluConfig}) ->
    throw new Error('deviceType is required') unless @deviceType?
    {@uuid, @privateKey} = meshbluConfig
    @meshblu = new MeshbluHTTP meshbluConfig

  createUserDevice: ({authorizedUuid}, callback) =>
    userDeviceConfig = userDeviceConfigGenerator
      authorizedUuid: authorizedUuid
      credentialsUuid: @uuid
      deviceType: @deviceType
      imageUrl: @imageUrl

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

  getUserDevices: (callback) =>
    @meshblu.subscriptions @uuid, (error, subscriptions) =>
      return callback error if error?
      return callback null, @_userDevicesFromSubscriptions subscriptions

  getUuid: => @uuid

  update: ({authorizedUuid, resourceOwnerSecrets}, callback) =>
    encryption = Encryption.fromJustGuess @privateKey

    update = credentialsDeviceUpdateGenerator({
      authorizedUuid: authorizedUuid
      resourceOwnerSecrets: encryption.encryptOptions resourceOwnerSecrets
      serviceUrl: @serviceUrl
    })

    @meshblu.updateDangerously @uuid, update, (error) =>
      return callback error if error?
      subscription = {subscriberUuid: @uuid, emitterUuid: @uuid, type: 'message.received'}
      @meshblu.createSubscription subscription, (error) =>
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
