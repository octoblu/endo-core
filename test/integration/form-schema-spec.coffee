{afterEach, beforeEach, describe, it} = global
{expect} = require 'chai'
sinon    = require 'sinon'

fs            = require 'fs'
Encryption    = require 'meshblu-encryption'
request       = require 'request'
enableDestroy = require 'server-destroy'
shmock        = require 'shmock'

MockStrategy  = require '../mock-strategy'
Server        = require '../..'

describe 'form schema', ->
  beforeEach (done) ->
    @privateKey = fs.readFileSync "#{__dirname}/../data/private-key.pem", 'utf8'
    @encryption = Encryption.fromPem @privateKey

    encrypted =
      secrets:
        credentials:
          secret: 'this is secret'

    @encrypted = @encryption.encrypt encrypted
    @publicKey = @encryption.key.exportKey 'public'
    @meshblu   = shmock 0xd00d

    enableDestroy @meshblu
    @apiStrategy = new MockStrategy name: 'api'
    @octobluStrategy = new MockStrategy name: 'octoblu'
    @messageHandler = formSchema: sinon.stub()

    @meshblu
      .get '/v2/whoami'
      .set 'Authorization', "Basic cGV0ZXI6aS1jb3VsZC1lYXQ="
      .reply 200, {
        options:
          imageUrl: "http://this-is-an-image.exe"
      }

    @meshblu
      .get '/publickey'
      .reply 200, {@publicKey}

    serverOptions =
      logFn: ->
      port: undefined,
      disableLogging: true
      apiStrategy: @apiStrategy
      octobluStrategy: @octobluStrategy
      messageHandler: @messageHandler
      serviceUrl: 'http://octoblu.xxx'
      deviceType: 'endo-endor'
      meshbluConfig:
        hostname: 'localhost'
        protocol: 'http'
        port: 0xd00d
        uuid: 'peter'
        token: 'i-could-eat'
        privateKey: @privateKey
      appOctobluHost: 'http://app.octoblu.bikes'
      userDeviceManagerUrl: 'http://manage-my.endo'
      meshbluPublicKeyUri: 'http://localhost:53261/publickey'
      healthcheckService: healthcheck: =>

    @server = new Server serverOptions

    @server.run (error) =>
      return done error if error?
      @serverPort = @server.address().port
      done()

  afterEach (done) ->
    @server.stop done

  afterEach (done) ->
    @meshblu.destroy done

  describe 'On GET /v1/form-schema', ->
    describe 'when the message-handler yields an empty object', ->
      beforeEach (done) ->
        @messageHandler.formSchema.yields null, {}

        options =
          baseUrl: "http://localhost:#{@serverPort}"
          json: true

        request.get '/v1/form-schema', options, (error, @response, @body) =>
          done error

      it 'should return a 200', ->
        expect(@response.statusCode).to.equal 200, JSON.stringify @body

      it 'should return the empty object', ->
        expect(@body).to.deep.equal {}

    describe 'when the message-handler yields a larger schema', ->
      beforeEach (done) ->
        @messageHandler.formSchema.yields null, {
          doSomething:
            type: 'object'
            required: ['name', 'color']
            properties:
              name:
                type: 'string'
              color:
                type: 'string'
        }

        options =
          baseUrl: "http://localhost:#{@serverPort}"
          json: true

        request.get '/v1/form-schema', options, (error, @response, @body) =>
          done error

      it 'should return a 200', ->
        expect(@response.statusCode).to.equal 200, JSON.stringify @body

      it 'should return the schema', ->
        expect(@body).to.deep.equal {
          doSomething:
            type: 'object'
            required: ['name', 'color']
            properties:
              name:
                type: 'string'
              color:
                type: 'string'
        }

    describe 'when the message-handler yields an error', ->
      beforeEach (done) ->
        error = new Error 'Something is awry'
        error.code = 418
        @messageHandler.formSchema.yields error

        options =
          baseUrl: "http://localhost:#{@serverPort}"
          json: true

        request.get '/v1/form-schema', options, (error, @response, @body) =>
          done error

      it 'should return a 418', ->
        expect(@response.statusCode).to.equal 418, JSON.stringify @body

      it 'should return the schema', ->
        expect(@body).to.deep.equal error: 'Something is awry'
