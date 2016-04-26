module.exports = ({authorizedUuid, resourceOwnerName, resourceOwnerSecrets, serviceUrl}) ->
  $set:
    'endo.authorizedUuid':       authorizedUuid
    'endo.resourceOwnerName':    resourceOwnerName
    'endo.resourceOwnerSecrets': resourceOwnerSecrets
    'meshblu.forwarders.message.received': [{
      type: 'webhook'
      url:  "#{serviceUrl}/messages",
      method: 'POST'
      generateAndForwardMeshbluCredentials: true
    }]
