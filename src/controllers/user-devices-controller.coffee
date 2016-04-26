class UserDevicesController
  constructor: ({@credentialsDeviceService}) ->
    throw new Error 'credentialsDeviceService is required' unless @credentialsDeviceService?

  create: (req, res) =>
    {credentialsDeviceUuid} = req.params
    authorizedUuid = req.meshbluAuth.uuid
    @credentialsDeviceService.authorizedFindByUuid {authorizedUuid, credentialsDeviceUuid}, (error, credentialsDevice) =>
      return res.sendError error if error?
      credentialsDevice.createUserDevice {authorizedUuid}, (error, userDevice) =>
        return res.sendError error if error?
        res.status(201).send userDevice

  delete: (req, res) =>
    {credentialsDeviceUuid, userDeviceUuid} = req.params
    authorizedUuid = req.meshbluAuth.uuid

    @credentialsDeviceService.authorizedFindByUuid {authorizedUuid, credentialsDeviceUuid}, (error, credentialsDevice) =>
      return res.sendError error if error?

      credentialsDevice.deleteUserDeviceSubscription {userDeviceUuid}, (error) =>
        return res.sendError error if error?
        res.sendStatus 204

  list: (req, res) =>
    {credentialsDeviceUuid} = req.params
    authorizedUuid = req.meshbluAuth.uuid
    @credentialsDeviceService.authorizedFindByUuid {authorizedUuid, credentialsDeviceUuid}, (error, credentialsDevice) =>
      return res.sendError error if error?
      credentialsDevice.getUserDevices (error, userDevices) =>
        return res.sendError error if error?
        res.send userDevices


module.exports = UserDevicesController
