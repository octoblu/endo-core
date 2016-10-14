_           = require 'lodash'
debug       = require('debug')('endo-core:messages-v2-controller')

class MessagesV2Controller
  constructor: ({@messageRouter}) ->

  create: (req, res) =>
    route     = JSON.parse req.get('x-meshblu-route') if req.get('x-meshblu-route')?
    message   = req.body
    respondTo = _.get message, 'metadata.respondTo'
    @messageRouter.route {message, route, respondTo}, (error) =>
      return res.sendError error if error?
      res.sendStatus 201

module.exports = MessagesV2Controller
