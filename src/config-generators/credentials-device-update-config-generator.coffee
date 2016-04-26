module.exports = ({authorizedUuid, resourceOwnerSecrets, serviceUrl}) ->
  $set:
    'endo.authorizedUuid':       authorizedUuid
    'endo.resourceOwnerSecrets': resourceOwnerSecrets
    'meshblu.forwarders.message.received': [{
      type: 'webhook'
      url:  "#{serviceUrl}/messages"
      method: 'POST'
      generateAndForwardMeshbluCredentials: true
    }]
