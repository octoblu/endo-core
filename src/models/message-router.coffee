RouteParser = require './route-parser'

class MessageRouter
  constructor: ({@credentialsDeviceService, @messagesService, @meshbluConfig})->

  route: ({auth, message, route, respondTo}, callback) =>
    routeParser = new RouteParser {route, serviceUuid: @meshbluConfig.uuid}
    return callback @_badRouteError() if routeParser.isBadRoute()

    {credentialsUuid, userDeviceUuid, senderUuid} = routeParser.parse()
    @credentialsDeviceService.getEndoByUuid credentialsUuid, (error, endo) =>
      return @_respondWithError {auth, senderUuid, userDeviceUuid, error, respondTo}, callback if error?

      @messagesService.send {endo, message}, (error, response) =>
        return @_respondWithError {auth, senderUuid, userDeviceUuid, error, respondTo}, callback if error?

        @messagesService.reply {auth, userDeviceUuid, senderUuid, response, respondTo}, (error) =>
          return @_respondWithError {auth, senderUuid, userDeviceUuid, error, respondTo}, callback if error?
          callback()

  _respondWithError: ({auth, senderUuid, userDeviceUuid, error, respondTo}, callback) =>
    @messagesService.replyWithError {auth, senderUuid, userDeviceUuid, error, respondTo}, (newError) =>
      return callback newError if newError?
      callback error

  _badRouteError: =>
    error = new Error "Bad route"
    error.code = 422
    return error

module.exports = MessageRouter
