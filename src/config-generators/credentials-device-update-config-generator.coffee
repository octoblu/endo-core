module.exports = ({authorizedUuid, secrets, serviceUrl}) ->
  $set:
    'endo.authorizedUuid': authorizedUuid
    'endo.secrets':        secrets
    'meshblu.forwarders.message.received': [{
      type: 'webhook'
      url:  "#{serviceUrl}/messages",
      method: 'POST'
      generateAndForwardMeshbluCredentials: true
    }]
