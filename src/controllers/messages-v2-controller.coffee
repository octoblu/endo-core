_           = require 'lodash'

class MessagesV2Controller
  constructor: ({@messageRouter}) ->

  create: (req, res) =>
    route     = JSON.parse req.get('x-meshblu-route') if req.get('x-meshblu-route')?
    message   = req.body
    respondTo = _.get message, 'metadata.respondTo'

    hasResponded = false
    @messageRouter.route {message, route, respondTo}, (error) =>
      return console.error 'warning: callback was called twice' if hasResponded
      hasResponded = true
      return res.sendError error if error?
      res.sendStatus 201

module.exports = MessagesV2Controller
