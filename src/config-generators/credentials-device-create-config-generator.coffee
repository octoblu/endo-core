
module.exports = ({serviceUuid}) ->
  meshblu:
    version: '2.0.0'
    whitelists:
      discover:
        view: [{uuid: serviceUuid}]
      configure:
        update: [{uuid: serviceUuid}]
