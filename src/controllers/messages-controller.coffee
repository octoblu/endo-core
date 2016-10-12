_     = require 'lodash'
debug = require('debug')('endo-core:messages-controller')

class MessagesController
  constructor: ({@credentialsDeviceService, @messagesService}) ->

  create: (req, res) =>
    route     = JSON.parse req.get('x-meshblu-route') if req.get('x-meshblu-route')?
    auth      = req.meshbluAuth
    message   = req.body
    respondTo = _.get message, 'metadata.respondTo'

    debug 'create', auth.uuid
    return @respondWithError {error: @_badRouteError(), auth, res, route, respondTo} if @_isBadRoute route

    @credentialsDeviceService.getEndoByUuid auth.uuid, (error, endo) =>
      debug 'credentialsDeviceService.getEndoByUuid', error
      return @respondWithError {auth, error, res, route, respondTo} if error?

      @messagesService.send {auth, endo, message}, (error, response) =>
        debug 'messagesService.send', error
        return @respondWithError {auth, error, res, route, respondTo} if error?

        @messagesService.reply {auth, route, response, respondTo}, (error) =>
          debug 'messagesService.reply', error
          return @respondWithError {auth, error, res, route, respondTo} if error?

          res.sendStatus 201

  _isBadRoute: (route) =>
    return true unless route?
    userDeviceUuid = _.nth(route, -2).from
    return _.some route, (hop) =>
      hop.type == 'message.received' && hop.from == userDeviceUuid && hop.to == userDeviceUuid

  _badRouteError: =>
    error = new Error("Bad route - This message was the result of a user device's subscription to itself.")
    error.code = 422
    return error

  respondWithError: ({auth, error, res, route, respondTo}) =>
    @messagesService.replyWithError {auth, error, route, respondTo}, (newError) =>
      return res.sendError newError if newError?
      return res.sendError error


module.exports = MessagesController
