module.exports = ({authorizedUuid, credentialsUuid, deviceType, imageUrl, messageSchemaUri, resourceOwnerName}) ->
  name: resourceOwnerName
  type: deviceType
  logo: imageUrl
  owner: authorizedUuid
  online: true
  octoblu:
    flow:
      forwardMetadata: true
  schemas:
    version: '1.0.0'
    message:
      $ref: messageSchemaUri
  meshblu:
    version: '2.0.0'
    whitelists:
      broadcast:
        as:       [{uuid: authorizedUuid}]
        received: [{uuid: authorizedUuid}]
        sent:     [{uuid: authorizedUuid}]
      configure:
        as:       [{uuid: authorizedUuid}]
        received: [{uuid: authorizedUuid}]
        sent:     [{uuid: authorizedUuid}]
        update:   [{uuid: authorizedUuid}]
      discover:
        view:     [{uuid: authorizedUuid}]
        as:       [{uuid: authorizedUuid}]
      message:
        as:       [{uuid: authorizedUuid}, {uuid: credentialsUuid}]
        received: [{uuid: authorizedUuid}, {uuid: credentialsUuid}]
        sent:     [{uuid: authorizedUuid}]
        from:     [{uuid: authorizedUuid}]
