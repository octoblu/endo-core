_ = require 'lodash'
url = require 'url'

class CredentialsDeviceController
  constructor: ({@credentialsDeviceService, @serviceUrl, @userDeviceManagerUrl}) ->
    throw new Error 'credentialsDeviceService is required' unless @credentialsDeviceService?
    throw new Error 'serviceUrl is required' unless @serviceUrl?
    throw new Error 'userDeviceManagerUrl is required' unless @userDeviceManagerUrl?

  upsert: (req, res) =>
    {resourceOwnerID, resourceOwnerSecrets} = req.user
    authorizedUuid = req.meshbluAuth.uuid

    @credentialsDeviceService.findOrCreate resourceOwnerID, (error, credentialsDevice) =>
      return res.sendError error if error?

      credentialsDevice.update {resourceOwnerSecrets, authorizedUuid}, (error) =>
        return res.sendError error if error?

        serviceUrl = url.parse @serviceUrl
        serviceUrl.pathname = credentialsDevice.getUuid()

        userDeviceManagerUrl = url.parse @userDeviceManagerUrl, true
        userDeviceManagerUrl.query.meshbluAuthBearer = req.meshbluAuth.bearerToken
        userDeviceManagerUrl.query.credentialsDeviceUrl = url.format serviceUrl

        return res.redirect url.format userDeviceManagerUrl

module.exports = CredentialsDeviceController
