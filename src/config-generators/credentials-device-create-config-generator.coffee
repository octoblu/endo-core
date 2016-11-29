
module.exports = ({serviceUuid}) ->
  meshblu:
    version: '2.0.0'
    whitelists:
      discover:
        view: [{uuid: serviceUuid}]
        as: [{uuid: serviceUuid}]
      configure:
        update: [{uuid: serviceUuid}]
      message:
        received: [{uuid: serviceUuid}]
