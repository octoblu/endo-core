
module.exports = ({userDeviceUuid, authorizedUuid}) ->
  type: 'status-device'
  owner: userDeviceUuid
  meshblu:
    whitelists:
      version: '2.0.0'
      configure:
        update: [
          {uuid: userDeviceUuid}
          {uuid: authorizedUuid}
        ]
        sent: [
          {uuid: userDeviceUuid}
          {uuid: authorizedUuid}
        ]
      discover:
        view: [
          {uuid: userDeviceUuid}
          {uuid: authorizedUuid}
        ]
  status:
    errors: []
