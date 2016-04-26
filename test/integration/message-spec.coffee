_            = require 'lodash'
fs           = require 'fs'
path         = require 'path'
http         = require 'http'
request      = require 'request'
shmock       = require '@octoblu/shmock'
MockStrategy = require '../mock-strategy'
Server       = require '../../src/server'
Encryption  = require 'meshblu-encryption'

describe 'messages', ->
  beforeEach (done) ->
    @privateKey = fs.readFileSync "#{__dirname}/../data/private-key.pem", 'utf8'
    @encryption = Encryption.fromPem @privateKey

    @meshblu = shmock 0xd00d
    @apiStrategy = new MockStrategy name: 'api'
    @octobluStrategy = new MockStrategy name: 'octoblu'
    @messageHandlers = hello: sinon.stub()

    @meshblu
      .get '/v2/whoami'
      .set 'Authorization', "Basic cGV0ZXI6aS1jb3VsZC1lYXQ="
      .reply 200, {
        options:
          imageUrl: "http://this-is-an-image.exe"
      }

    serverOptions =
      logFn: ->
      port: undefined,
      disableLogging: true
      apiStrategy: @apiStrategy
      octobluStrategy: @octobluStrategy
      messageHandlers: @messageHandlers
      schemas:
        hello:   require '../data/schemas/hello-schema.json'
        namaste: require '../data/schemas/namaste-schema.json'
      serviceUrl: 'http://octoblu.xxx'
      deviceType: 'endo-endor'
      meshbluConfig:
        server: 'localhost'
        port: 0xd00d
        uuid: 'peter'
        token: 'i-could-eat'
        privateKey: @privateKey

    @server = new Server serverOptions

    @server.run (error) =>
      return done error if error?
      @serverPort = @server.address().port
      done()

  afterEach (done) ->
    @server.stop done

  afterEach (done) ->
    @meshblu.close done

  describe 'On POST /messages', ->
    describe 'when authorized', ->
      beforeEach ->
        userAuth = new Buffer('some-uuid:some-token').toString 'base64'
        serviceAuth = new Buffer('peter:i-could-eat').toString 'base64'
        @credentialsDeviceAuth = new Buffer('cred-uuid:cred-token').toString 'base64'
        @meshblu
          .get '/v2/whoami'
          .set 'Authorization', "Basic #{@credentialsDeviceAuth}"
          .reply 200,
            uuid: 'cred-uuid'
            endo:
              resourceOwnerSecrets: @encryption.encryptOptions secret: 'decryptedClientSecret'

        @meshblu
          .get '/v2/devices/cred-uuid'
          .set 'Authorization', "Basic #{serviceAuth}"
          .reply 200,
            uuid: 'cred-uuid'
            endo:
              resourceOwnerSecrets: @encryption.encryptOptions secret: 'decryptedClientSecret'

      describe 'when called with a message without metadata', ->
        beforeEach (done) ->
          options =
            baseUrl: "http://localhost:#{@serverPort}"
            json:
              data:
                greeting: 'hola'
            auth:
              username: 'cred-uuid'
              password: 'cred-token'

          request.post '/messages', options, (error, @response, @body) =>
            done error

        it 'should return a 422', ->
          expect(@response.statusCode).to.equal 422, JSON.stringify(@body)

      describe 'when called with valid metadata, but an invalid jobType', ->
        beforeEach (done) ->
          options =
            baseUrl: "http://localhost:#{@serverPort}"
            json:
              metadata:
                jobType: 'goodbye'
            auth:
              username: 'cred-uuid'
              password: 'cred-token'

          request.post '/messages', options, (error, @response, @body) =>
            done error

        it 'should return a 422', ->
          expect(@response.statusCode).to.equal 422, JSON.stringify(@body)

      describe 'when called with valid metadata, valid jobType, but invalid data', ->
        beforeEach (done) ->
          options =
            baseUrl: "http://localhost:#{@serverPort}"
            auth:
              username: 'cred-uuid'
              password: 'cred-token'
            headers:
              'x-meshblu-route': JSON.stringify [
                {"from": "flow-uuid", "to": "user-device", "type": "message.sent"}
                {"from": "user-device", "to": "cred-uuid", "type": "message.received"}
              ]
            json:
              metadata:
                jobType: 'hello'
              data:
                greeting: {
                  salutation: 'hail fellow well met'
                }

          request.post '/messages', options, (error, @response, @body) =>
            done error

        it 'should return a 422', ->
          expect(@response.statusCode).to.equal 422

      describe 'when called with a valid message, but the handler does not implement the method', ->
        beforeEach (done) ->
          options =
            baseUrl: "http://localhost:#{@serverPort}"
            headers:
              'x-meshblu-route': JSON.stringify [
                {"from": "flow-uuid", "to": "user-device", "type": "message.sent"}
                {"from": "user-device", "to": "cred-uuid", "type": "message.received"}
              ]
            json:
              metadata:
                jobType: 'namaste'
              data:
                greeting: 'hola'
            auth:
              username: 'cred-uuid'
              password: 'cred-token'

          request.post '/messages', options, (error, @response, @body) =>
            done error

        it 'should return a 501', ->
          expect(@response.statusCode).to.equal 501, JSON.stringify(@body)

      describe 'when called with a valid message', ->
        beforeEach (done) ->
          @messageHandlers.hello.yields null, 200, whatever: 'this is a response'
          @responseHandler = @meshblu
            .post '/messages'
            .set 'Authorization', "Basic #{@credentialsDeviceAuth}"
            .set 'x-meshblu-as', 'user-device'
            .send
              devices: ['flow-uuid']
              metadata:
                code: 200
              data:
                whatever: 'this is a response'
            .reply 201

          options =
            baseUrl: "http://localhost:#{@serverPort}"
            headers:
              'x-meshblu-route': JSON.stringify [
                {"from": "flow-uuid", "to": "user-device", "type": "message.sent"}
                {"from": "user-device", "to": "cred-uuid", "type": "message.received"}
              ]
            json:
              metadata:
                jobType: 'hello'
              data:
                greeting: 'hola'
            auth:
              username: 'cred-uuid'
              password: 'cred-token'

          request.post '/messages', options, (error, @response, @body) =>
            done error

        it 'should return a 201', ->
          expect(@response.statusCode).to.equal 201, JSON.stringify @body

        it 'should respond to the message via meshblu', ->
          @responseHandler.done()

        it 'should call the hello messageHandler with the message and auth', ->
          expect(@messageHandlers.hello).to.have.been.calledWith sinon.match {
            auth:
              uuid: 'cred-uuid'
              token: 'cred-token'
            data:
              greeting: 'hola'
            endo:
              resourceOwnerSecrets:
                secret: 'decryptedClientSecret'
          }

      describe 'when called with a valid message, but theres an error', ->
        beforeEach (done) ->
          @messageHandlers.hello.yields new Error 'Something very bad happened'
          @responseHandler = @meshblu
            .post '/messages'
            .set 'Authorization', "Basic #{@credentialsDeviceAuth}"
            .set 'x-meshblu-as', 'user-device'
            .send
              devices: ['flow-uuid']
              metadata:
                code: 500
                error:
                  message: 'Something very bad happened'
            .reply 201

          options =
            baseUrl: "http://localhost:#{@serverPort}"
            headers:
              'x-meshblu-route': JSON.stringify [
                {"from": "flow-uuid", "to": "user-device", "type": "message.sent"}
                {"from": "user-device", "to": "cred-uuid", "type": "message.received"}
              ]
            json:
              metadata:
                jobType: 'hello'
              data:
                greeting: 'hola'
            auth:
              username: 'cred-uuid'
              password: 'cred-token'

          request.post '/messages', options, (error, @response, @body) =>
            done error

        it 'should call the hello messageHandler with the message and auth', ->
          expect(@messageHandlers.hello).to.have.been.calledWith sinon.match {
            auth:
              uuid: 'cred-uuid'
              token: 'cred-token'
            data:
              greeting: 'hola'
            endo:
              resourceOwnerSecrets:
                secret: 'decryptedClientSecret'
          }

        it 'should return a 500', ->
          expect(@response.statusCode).to.equal 500, JSON.stringify @body

        it 'should respond to the message with the error via meshblu', ->
          @responseHandler.done()
