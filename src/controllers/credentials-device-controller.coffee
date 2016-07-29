url = require 'url'

class CredentialsDeviceController
  constructor: ({@credentialsDeviceService, @appOctobluHost, @serviceUrl, @userDeviceManagerUrl}) ->
    throw new Error 'appOctobluHost is required' unless @appOctobluHost?
    throw new Error 'credentialsDeviceService is required' unless @credentialsDeviceService?
    throw new Error 'serviceUrl is required' unless @serviceUrl?
    throw new Error 'userDeviceManagerUrl is required' unless @userDeviceManagerUrl?

  getCredentialsDevice: (req, res, next) =>
    {credentialsDeviceUuid} = req.params
    authorizedUuid = req.meshbluAuth.uuid

    @credentialsDeviceService.authorizedFind {authorizedUuid, credentialsDeviceUuid}, (error, credentialsDevice) =>
      return res.sendError error if error?
      req.credentialsDevice = credentialsDevice
      next()

  get: (req, res) =>
    req.credentialsDevice.getPublicDevice (error, publicDevice) =>
      return res.sendError error if error?
      res.send publicDevice

  upsert: (req, res) =>
    encrypted = req.user
    {id} = req.user

    authorizedUuid = req.meshbluAuth.uuid

    @credentialsDeviceService.findOrCreate id, (error, credentialsDevice) =>
      return res.sendError error if error?

      credentialsDevice.update {authorizedUuid, id, encrypted}, (error) =>
        return res.sendError error if error?

        serviceUrl = url.parse @serviceUrl
        serviceUrl.pathname = "/credentials/#{credentialsDevice.getUuid()}"

        userDeviceManagerUrl = url.parse @userDeviceManagerUrl, true
        userDeviceManagerUrl.query.meshbluAuthBearer = req.meshbluAuth.bearerToken
        userDeviceManagerUrl.query.credentialsDeviceUrl = url.format serviceUrl
        userDeviceManagerUrl.query.appOctobluHost = url.format @appOctobluHost

        return res.redirect 301, url.format(userDeviceManagerUrl)

module.exports = CredentialsDeviceController
