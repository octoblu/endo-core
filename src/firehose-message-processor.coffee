MeshbluFirehose = require 'meshblu-firehose-socket.io'
debug           = require('debug')('endo-core:firehose-message-processor')
_               = require 'lodash'

class FirehoseMessageProcessor
  constructor: ({@meshbluConfig, @messageRouter}) ->
    throw new Error 'meshbluConfig is required' unless @meshbluConfig?
    throw new Error 'messageRouter is required' unless @messageRouter?
    @firehose = new MeshbluFirehose {@meshbluConfig}
    @firehose.on 'message', @_onMessage

  run: (callback) =>
    @firehose.connect callback

  _onMessage: ({metadata, data}) =>
    {route} = metadata
    message = data
    respondTo = _.get message, 'metadata.respondTo'
    
    @messageRouter.route {message, route, respondTo}, (error) =>

  stop: (callback) =>
    @firehose.close callback


module.exports = FirehoseMessageProcessor
