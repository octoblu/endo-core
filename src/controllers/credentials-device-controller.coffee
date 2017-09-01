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

  upsertWithRedirect: (req, res) =>
    @_upsert req, res, (error, {userDeviceManagerUrl, uuid}={})=>
      return res.sendError error if error?
      return res.redirect 301, url.format(userDeviceManagerUrl) if req.accepts('html')
      return res.status(201).send({uuid})

  upsertWithoutRedirect: (req, res) =>
    @_upsert req, res, (error, {userDeviceManagerUrl, uuid})=>
      return res.sendError error if error?
      if req.accepts 'html'
        res.set location: url.format(userDeviceManagerUrl)
        return res.status(201).end()

      return res.status(201).send({uuid})

  _upsert: (req, res, callback) =>
    encrypted = req.user
    {id} = req.user
    
    authorizedUuid = req.meshbluAuth.uuid

    @credentialsDeviceService.findOrCreate id, (error, credentialsDevice) =>
      return callback error if error?

      credentialsDevice.update {authorizedUuid, id, encrypted}, (error) =>
        return callback error if error?
        uuid = credentialsDevice.getUuid()
        serviceUrl = url.parse @serviceUrl
        serviceUrl.pathname = "/credentials/#{uuid}"

        userDeviceManagerUrl = url.parse @userDeviceManagerUrl, true
        userDeviceManagerUrl.query.meshbluAuthBearer = req.meshbluAuth.bearerToken
        userDeviceManagerUrl.query.credentialsDeviceUrl = url.format serviceUrl
        userDeviceManagerUrl.query.appOctobluHost = url.format @appOctobluHost

        callback(null, {uuid, userDeviceManagerUrl})

module.exports = CredentialsDeviceController
