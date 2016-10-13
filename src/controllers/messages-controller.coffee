_           = require 'lodash'
debug       = require('debug')('endo-core:messages-controller')

class MessagesController
  constructor: ({@messageRouter}) ->

  create: (req, res) =>
    route     = JSON.parse req.get('x-meshblu-route') if req.get('x-meshblu-route')?
    auth      = req.meshbluAuth
    message   = req.body
    respondTo = _.get message, 'metadata.respondTo'

    @messageRouter.route {auth, message, route, respondTo}, (error) =>
      return res.sendError error if error?
      res.sendStatus 201

module.exports = MessagesController
