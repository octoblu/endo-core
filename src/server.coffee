bodyParser         = require 'body-parser'
cookieParser       = require 'cookie-parser'
cookieSession      = require 'cookie-session'
cors               = require 'cors'
errorHandler       = require 'errorhandler'
express            = require 'express'
meshbluHealthcheck = require 'express-meshblu-healthcheck'
expressVersion     = require 'express-package-version'
sendError          = require 'express-send-error'
_                  = require 'lodash'
MeshbluHttp        = require 'meshblu-http'
morgan             = require 'morgan'
path               = require 'path'
passport           = require 'passport'
favicon            = require 'serve-favicon'

Router                   = require './router'
debug                    = require('debug')('endo-core:server')

class Server
  constructor: (options) ->
    {
      @apiStrategy
      @appOctobluHost
      @credentialsDeviceService
      @disableLogging
      @healthcheckService
      @logFn
      @meshbluConfig
      @messagesService
      @messageRouter
      @meshbluPublicKeyUri = 'https://meshblu.octoblu.com/publickey'
      @octobluStrategy
      @port
      @serviceUrl
      @skipRedirectAfterApiAuth
      @staticSchemasPath
      @userDeviceManagerUrl
    } = options

    throw new Error('apiStrategy is required') unless @apiStrategy?
    throw new Error('appOctobluHost is required') unless @appOctobluHost?
    throw new Error('meshbluConfig is required') unless @meshbluConfig?
    throw new Error('octobluStrategy is required') unless @octobluStrategy?
    throw new Error('serviceUrl is required') unless @serviceUrl?
    throw new Error('userDeviceManagerUrl is required') unless @userDeviceManagerUrl?

    throw new Error('messageRouter is required') unless @messageRouter?
    throw new Error('messagesService is required') unless @messagesService?
    throw new Error('credentialsDeviceService is required') unless @credentialsDeviceService?

    throw new Error 'healthcheckService is required' unless @healthcheckService?
    throw new Error 'healthcheckService.healthcheck is not a function (and must be)' unless _.isFunction @healthcheckService.healthcheck

  address: =>
    @server.address()

  run: (callback) =>
    debug 'running server'
    meshblu = new MeshbluHttp _.cloneDeep(@meshbluConfig)
    meshblu.getServerPublicKey (error, publicKey) =>
      if error?
        console.error "Error fetching public key: #{error.message}"
        process.exit 1
        return

      passport.serializeUser   (user, done) => done null, user
      passport.deserializeUser (user, done) => done null, user

      passport.use 'octoblu', @octobluStrategy
      passport.use 'api', @apiStrategy

      app = express()
      app.use favicon path.join(__dirname, '../favicon.ico')
      app.use meshbluHealthcheck()
      app.use expressVersion format: '{"version": "%s"}'
      app.use morgan 'dev', immediate: false unless @disableLogging
      app.use cors(exposedHeaders: ['Location'])
      app.use errorHandler()
      app.use cookieSession secret: @meshbluConfig.token
      app.use cookieParser()
      app.use passport.initialize()
      app.use passport.session()
      app.use bodyParser.urlencoded limit: '1mb', extended : true
      app.use bodyParser.json limit : '1mb'
      app.use sendError {@logFn}
      app.options '*', cors()

      router = new Router {
        @credentialsDeviceService
        @meshbluConfig
        @messageRouter
        @messagesService
        meshbluPublicKey: publicKey
        @appOctobluHost
        @healthcheckService
        @serviceUrl
        @userDeviceManagerUrl
        @staticSchemasPath
        @skipRedirectAfterApiAuth
        @skipMessageRoutes
      }

      router.route app

      @server = app.listen @port, callback

  stop: (callback) =>
    @server.close callback

module.exports = Server
