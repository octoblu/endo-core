MeshbluAuth = require 'express-meshblu-auth'
passport    = require 'passport'

CredentialsDeviceController = require './controllers/credentials-device-controller'
FormSchemaController        = require './controllers/form-schema-controller'
MessagesController          = require './controllers/messages-controller'
MessageSchemaController     = require './controllers/message-schema-controller'
OctobluAuthController       = require './controllers/octoblu-auth-controller'
ResponseSchemaController    = require './controllers/response-schema-controller'
UserDevicesController       = require './controllers/user-devices-controller'

class Router
  constructor: (options) ->
    {@appOctobluHost, @credentialsDeviceService, @messagesService} = options
    {@meshbluConfig, @serviceUrl, @userDeviceManagerUrl} = options

    throw new Error 'appOctobluHost is required' unless @appOctobluHost?
    throw new Error 'credentialsDeviceService is required' unless @credentialsDeviceService?
    throw new Error 'meshbluConfig is required' unless @meshbluConfig?
    throw new Error 'messagesService is required' unless @messagesService?
    throw new Error 'serviceUrl is required' unless @serviceUrl?
    throw new Error 'userDeviceManagerUrl is required' unless @userDeviceManagerUrl?

    @credentialsDeviceController = new CredentialsDeviceController {@credentialsDeviceService, @appOctobluHost, @serviceUrl, @userDeviceManagerUrl}
    @formSchemaController        = new FormSchemaController {@messagesService}
    @messagesController          = new MessagesController {@credentialsDeviceService, @messagesService}
    @messageSchemaController     = new MessageSchemaController {@messagesService}
    @octobluAuthController       = new OctobluAuthController
    @responseSchemaController    = new ResponseSchemaController {@messagesService}
    @userDevicesController       = new UserDevicesController

  route: (app) =>
    meshbluAuth = new MeshbluAuth @meshbluConfig

    app.get '/v1/form-schema', @formSchemaController.list
    app.get '/v1/message-schema', @messageSchemaController.list
    app.get '/v1/response-schema', @responseSchemaController.list

    app.get '/auth/octoblu', passport.authenticate('octoblu')
    app.get '/auth/octoblu/callback', passport.authenticate('octoblu', failureRedirect: '/auth/octoblu'), @octobluAuthController.storeAuthAndRedirect

    app.use meshbluAuth.auth()
    app.use meshbluAuth.gatewayRedirect('/auth/octoblu')

    app.get  '/auth/api', passport.authenticate('api')
    app.get  '/auth/api/callback', passport.authenticate('api'), @credentialsDeviceController.upsert

    app.post '/v1/messages', @messagesController.create

    app.all  '/:credentialsDeviceUuid*', @credentialsDeviceController.getCredentialsDevice
    app.get  '/:credentialsDeviceUuid', @credentialsDeviceController.get
    app.get  '/:credentialsDeviceUuid/user-devices', @userDevicesController.list
    app.post '/:credentialsDeviceUuid/user-devices', @userDevicesController.create
    app.delete  '/:credentialsDeviceUuid/user-devices/:userDeviceUuid', @userDevicesController.delete

    app.use (req, res) => res.redirect '/auth/api'

module.exports = Router
