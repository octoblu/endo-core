class UserDevicesController
  constructor: ({@credentialsDeviceService}) ->
    throw new Error 'credentialsDeviceService is required' unless @credentialsDeviceService?

  list: (req, res) =>
    {credentialsDeviceUuid} = req.params
    authorizedUuid = req.meshbluAuth.uuid
    @credentialsDeviceService.authorizedFindByUuid {authorizedUuid, credentialsDeviceUuid}, (error, credentialsDevice) =>
      return res.sendError error if error?
      credentialsDevice.getUserDevices (error, userDevices) =>
        return res.sendError error if error?
        res.send userDevices

  create: (req, res) =>
    {credentialsDeviceUuid} = req.params
    authorizedUuid = req.meshbluAuth.uuid
    @credentialsDeviceService.authorizedFindByUuid {authorizedUuid, credentialsDeviceUuid}, (error, credentialsDevice) =>
      return res.sendError error if error?
      credentialsDevice.createUserDevice {authorizedUuid}, (error, userDevice) =>
        return res.sendError error if error?
        res.status(201).send userDevice


module.exports = UserDevicesController
