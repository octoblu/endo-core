module.exports = ({endo, endoSignature, serviceUrl}) ->
  $set:
    'endo':               endo
    'endoSignature':      endoSignature
    'meshblu.forwarders.message.received': [{
      type: 'webhook'
      url:  "#{serviceUrl}/messages",
      method: 'POST'
      generateAndForwardMeshbluCredentials: true
    }]
