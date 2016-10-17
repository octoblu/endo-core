MeshbluFirehose = require 'meshblu-firehose-socket.io'

class FirehoseMessageProcessor
  constructor: ({@meshbluConfig, @messageRouter}) ->

    throw new Error 'meshbluConfig is required' unless @meshbluConfig?
    throw new Error 'messageRouter is required' unless @messageRouter?
    @firehose = new MeshbluFirehose {@meshbluConfig}
    @firehose.on 'message', @_onMessage

  run: (callback) =>
    debug 'running express server'
    @firehose.connect callback

  @_onMessage: ({metadata, data}) =>
    console.log "GOT A MESSAGE", {metadata, data}


module.exports = FirehoseMessageProcessor
