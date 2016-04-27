module.exports = ({authorizedKey, secrets, serviceUrl}) ->
  $set:
    'endo.authorizedKey': authorizedKey
    'endo.secrets':        secrets
    'meshblu.forwarders.message.received': [{
      type: 'webhook'
      url:  "#{serviceUrl}/messages",
      method: 'POST'
      generateAndForwardMeshbluCredentials: true
    }]
