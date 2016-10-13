MeshbluAuth                 = require 'express-meshblu-auth'
passport                    = require 'passport'
httpSignature               = require '@octoblu/connect-http-signature'
CredentialsDeviceController = require './controllers/credentials-device-controller'
FormSchemaController        = require './controllers/form-schema-controller'
MessagesController          = require './controllers/messages-controller'
MessagesV2Controller        = require './controllers/messages-v2-controller'
MessageSchemaController     = require './controllers/message-schema-controller'
OctobluAuthController       = require './controllers/octoblu-auth-controller'
ResponseSchemaController    = require './controllers/response-schema-controller'
StaticSchemasController     = require './controllers/static-schemas-controller'
UserDevicesController       = require './controllers/user-devices-controller'

class Router
  constructor: (options) ->
    {
      appOctobluHost
      credentialsDeviceService
      messageRouter
      messagesService
      @meshbluConfig
      @meshbluPublicKey
      serviceUrl
      userDeviceManagerUrl
      staticSchemasPath
      @skipRedirectAfterApiAuth
    } = options

    throw new Error 'appOctobluHost is required' unless appOctobluHost?
    throw new Error 'credentialsDeviceService is required' unless credentialsDeviceService?
    throw new Error 'meshbluConfig is required' unless @meshbluConfig?
    throw new Error 'meshbluPublicKey is required' unless @meshbluPublicKey?
    throw new Error 'messagesService is required' unless messagesService?
    throw new Error 'messageRouter is required' unless messageRouter?
    throw new Error 'serviceUrl is required' unless serviceUrl?
    throw new Error 'userDeviceManagerUrl is required' unless userDeviceManagerUrl?

    @credentialsDeviceController = new CredentialsDeviceController {credentialsDeviceService, appOctobluHost, serviceUrl, userDeviceManagerUrl}
    @formSchemaController        = new FormSchemaController {messagesService}
    @messagesController          = new MessagesController {messageRouter}
    @messagesV2Controller        = new MessagesV2Controller {messageRouter}
    @messageSchemaController     = new MessageSchemaController {messagesService}
    @octobluAuthController       = new OctobluAuthController
    @responseSchemaController    = new ResponseSchemaController {messagesService}
    @staticSchemasController     = new StaticSchemasController {staticSchemasPath}
    @userDevicesController       = new UserDevicesController

  route: (app) =>
    meshbluAuth = new MeshbluAuth @meshbluConfig

    app.get '/', (req, res) => res.redirect('/auth/octoblu')
    app.get '/v1/form-schema', @formSchemaController.list
    app.get '/v1/message-schema', @messageSchemaController.list
    app.get '/v1/response-schema', @responseSchemaController.list
    app.get '/schemas/:name', @staticSchemasController.get

    app.get '/auth/octoblu', passport.authenticate('octoblu')
    app.get '/auth/octoblu/callback', passport.authenticate('octoblu', failureRedirect: '/auth/octoblu'), @octobluAuthController.storeAuthAndRedirect

    app.use meshbluAuth.auth()
    app.use meshbluAuth.gatewayRedirect('/auth/octoblu')

    upsert = @credentialsDeviceController.upsertWithRedirect
    upsert = @credentialsDeviceController.upsertWithoutRedirect if @skipRedirectAfterApiAuth

    app.get  '/auth/api', passport.authenticate('api')
    app.get  '/auth/api/callback', passport.authenticate('api'), upsert
    app.post  '/auth/api/callback', passport.authenticate('api'), upsert

    app.post '/v1/messages', @messagesController.create
    app.post '/v2/messages', httpSignature.verify(pub: @meshbluPublicKey), httpSignature.gateway(), @messagesV2Controller.create

    app.all  '/credentials/:credentialsDeviceUuid*', @credentialsDeviceController.getCredentialsDevice
    app.get  '/credentials/:credentialsDeviceUuid', @credentialsDeviceController.get
    app.get  '/credentials/:credentialsDeviceUuid/user-devices', @userDevicesController.list
    app.post '/credentials/:credentialsDeviceUuid/user-devices', @userDevicesController.create
    app.delete  '/credentials/:credentialsDeviceUuid/user-devices/:userDeviceUuid', @userDevicesController.delete


    app.use (req, res) => res.redirect '/auth/api'

module.exports = Router
