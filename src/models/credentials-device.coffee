_           = require 'lodash'
MeshbluHTTP = require 'meshblu-http'
Encryption  = require 'meshblu-encryption'
url         = require 'url'

credentialsDeviceUpdateGenerator = require '../config-generators/credentials-device-update-config-generator'
userDeviceConfigGenerator = require '../config-generators/user-device-config-generator'

class CredentialsDevice
  constructor: ({@deviceType, @encrypted, @imageUrl, meshbluConfig, @serviceUrl, @serviceUuid}) ->
    throw new Error('deviceType is required') unless @deviceType?
    throw new Error('serviceUuid is required') unless @serviceUuid?
    {@uuid, @privateKey} = meshbluConfig

    @encryption = Encryption.fromJustGuess @privateKey
    @meshblu    = new MeshbluHTTP meshbluConfig

  createUserDevice: ({authorizedUuid}, callback) =>
    resourceOwnerName = @encryption.decrypt(@encrypted).username

    userDeviceConfig = userDeviceConfigGenerator
      authorizedUuid: authorizedUuid
      credentialsUuid: @uuid
      deviceType: @deviceType
      imageUrl: @imageUrl
      resourceOwnerName: resourceOwnerName
      formSchemaUrl: @_getFormSchemaUrl()
      messageSchemaUrl: @_getMessageSchemaUrl()
      responseSchemaUrl: @_getResponseSchemaUrl()

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
    @meshblu.device @serviceUuid, (error, credentialsDevice) =>
      return callback error if error?
      decrypted = @encryption.decrypt @encrypted
      decrypted = _.omit decrypted, 'secrets'
      return callback null, _.defaults({username: decrypted.username}, credentialsDevice.options)

  getUserDevices: (callback) =>
    @meshblu.subscriptions @uuid, (error, subscriptions) =>
      return callback error if error?
      return callback null, @_userDevicesFromSubscriptions subscriptions

  getUuid: => @uuid

  update: ({authorizedUuid, encrypted, id}, callback) =>
    {endo, endoSignature} = @_getSignedUpdate {authorizedUuid, encrypted, id}
    endo.encrypted = @encryption.encrypt endo.encrypted

    update = credentialsDeviceUpdateGenerator {endo, endoSignature, @serviceUrl}
    @meshblu.updateDangerously @uuid, update, callback

  _getFormSchemaUrl: =>
    uri = url.parse @serviceUrl
    uri.pathname = "#{uri.pathname}v1/form-schema"
    return url.format uri

  _getMessageSchemaUrl: =>
    uri = url.parse @serviceUrl
    uri.pathname = "#{uri.pathname}v1/message-schema"
    return url.format uri

  _getResponseSchemaUrl: =>
    uri = url.parse @serviceUrl
    uri.pathname = "#{uri.pathname}v1/response-schema"
    return url.format uri

  _getSignedUpdate: ({authorizedUuid, encrypted, id}) =>
    endo = {
      authorizedKey: @encryption.sign(authorizedUuid).toString 'base64'
      idKey:         @encryption.sign(id).toString 'base64'
      credentialsDeviceUuid: @uuid
      version: '1.0.0'
      encrypted: encrypted
    }
    endoSignature = @encryption.sign endo
    return {endo, endoSignature}

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
