module.exports = ({authorizedKey, secrets, secretsSignature, serviceUrl}) ->
  $set:
    'endo.authorizedKey': authorizedKey
    'endo.secrets':        secrets
    'endo.secretsSignature': secretsSignature
    'meshblu.forwarders.message.received': [{
      type: 'webhook'
      url:  "#{serviceUrl}/messages",
      method: 'POST'
      generateAndForwardMeshbluCredentials: true
    }]
