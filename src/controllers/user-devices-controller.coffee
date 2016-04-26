class UserDevicesController
  constructor: ({@credentialsDeviceService}) ->
    throw new Error 'credentialsDeviceService is required' unless @credentialsDeviceService?

  getCredentialsDevice: (req, res, next) =>
    {credentialsDeviceUuid} = req.params
    authorizedUuid = req.meshbluAuth.uuid

    @credentialsDeviceService.authorizedFindByUuid {authorizedUuid, credentialsDeviceUuid}, (error, credentialsDevice) =>
      return res.sendError error if error?
      req.credentialsDevice = credentialsDevice
      next()

  create: (req, res) =>
    authorizedUuid = req.meshbluAuth.uuid
    req.credentialsDevice.createUserDevice {authorizedUuid}, (error, userDevice) =>
      return res.sendError error if error?
      res.status(201).send userDevice

  delete: (req, res) =>
    {userDeviceUuid} = req.params

    req.credentialsDevice.deleteUserDeviceSubscription {userDeviceUuid}, (error) =>
      return res.sendError error if error?
      res.sendStatus 204

  list: (req, res) =>
    req.credentialsDevice.getUserDevices (error, userDevices) =>
      return res.sendError error if error?
      res.send userDevices


module.exports = UserDevicesController
