_ = require 'lodash'

class RouteParser
  constructor: ({@route, @serviceUuid}) ->

  isBadRoute: =>
    return true if _.isEmpty @route
    {userDeviceUuid} = @parse()

    return _.some @route, (hop) =>
      hop.type == 'message.received' && hop.from == userDeviceUuid && hop.to == userDeviceUuid

  parse: =>
    senderUuid     =  _.first(@route).from
    route =           _.reject @route, (hop) => hop.from == @serviceUuid || hop.to == @serviceUuid
    credentialsUuid = _.last(route).to
    route =           _.reject route, (hop) => hop.from == credentialsUuid
    userDeviceUuid =  _.last(route).from

    return {credentialsUuid, senderUuid, userDeviceUuid}
    
module.exports = RouteParser
