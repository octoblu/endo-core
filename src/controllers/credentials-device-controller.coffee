class CredentialsDeviceController
  constructor: ({@credentialsDeviceService}) ->

  upsert: (req, res) =>
    {resourceOwnerID, resourceOwnerSecrets} = req.user
    authorizedUuid = req.meshbluAuth.uuid

    @credentialsDeviceService.findOrCreate resourceOwnerID, (error, credentialsDevice) =>
      return res.sendError error if error?

      credentialsDevice.update {resourceOwnerSecrets, authorizedUuid}, (error) =>
        return res.sendError error if error?
        return res.redirect "/#{credentialsDevice.getUuid()}/user-devices"

module.exports = CredentialsDeviceController
