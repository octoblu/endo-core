{afterEach, beforeEach, describe, it} = global
{expect} = require 'chai'
sinon    = require 'sinon'

fs            = require 'fs'
request       = require 'request'
Encryption    = require 'meshblu-encryption'
enableDestroy = require 'server-destroy'
shmock        = require 'shmock'

MockStrategy  = require '../mock-strategy'
Server        = require '../..'
moment        = require 'moment'

describe 'messages', ->
  beforeEach (done) ->
    @privateKey = fs.readFileSync "#{__dirname}/../data/private-key.pem", 'utf8'
    @encryption = Encryption.fromPem @privateKey
    @publicKey  = @encryption.key.exportKey 'public'

    encrypted =
      secrets:
        credentials:
          secret: 'this is secret'
    @encrypted = @encryption.encrypt encrypted

    @meshblu = shmock()
    enableDestroy @meshblu
    @apiStrategy = new MockStrategy name: 'api'
    @octobluStrategy = new MockStrategy name: 'octoblu'
    @messageHandler = onMessage: sinon.stub()

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
        port: @meshblu.address().port
        uuid: 'peter'
        token: 'i-could-eat'
        privateKey: @privateKey
      appOctobluHost: 'http://app.octoblu.mom'
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

  describe 'On POST /v1/messages', ->
    describe 'when authorized', ->
      beforeEach ->
        @credentialsDeviceAuth = new Buffer('cred-uuid:cred-token').toString 'base64'
        @meshblu
          .post '/authenticate'
          .set 'Authorization', "Basic #{@credentialsDeviceAuth}"
          .reply 204

      describe 'when we get some weird device instead of a credentials device', ->
        beforeEach ->
          @meshblu
            .post '/search/devices'
            .set 'Authorization', "Basic #{@serviceAuth}"
            .set 'x-meshblu-as', 'cred-uuid'
            .send uuid: 'cred-uuid'
            .reply 200, [
              uuid: 'cred-uuid'
              banana: 'pudding'
            ]

        describe 'when called with a valid message', ->
          beforeEach (done) ->
            options =
              baseUrl: "http://localhost:#{@serverPort}"
              headers:
                'x-meshblu-route': JSON.stringify [
                  {"from": "flow-uuid", "to": "user-uuid", "type": "message.sent"}
                  {"from": "user-uuid", "to": "cred-uuid", "type": "message.received"}
                  {"from": "cred-uuid", "to": "cred-uuid", "type": "message.received"}
                ]
              json:
                metadata:
                  jobType: 'hello'
                data:
                  greeting: 'hola'
              auth:
                username: 'cred-uuid'
                password: 'cred-token'

            request.post '/v1/messages', options, (error, @response, @body) =>
              done error

          it 'should return a 404', ->
            expect(@response.statusCode).to.equal 404, JSON.stringify @body

      describe 'when we get an invalid credentials device', ->
        beforeEach ->
          @meshblu
            .post '/search/devices'
            .set 'Authorization', "Basic #{@serviceAuth}"
            .set 'x-meshblu-as', 'cred-uuid'
            .send uuid: 'cred-uuid'
            .reply 200, [
              uuid: 'cred-uuid'
              endoSignature: 'John Hancock. Definitely, definitely John Hancock'
              endo:
                credentialsDeviceUuid: 'cred-uuid'
                encrypted: @encrypted
            ]

        describe 'when called with a valid message', ->
          beforeEach (done) ->
            options =
              baseUrl: "http://localhost:#{@serverPort}"
              headers:
                'x-meshblu-route': JSON.stringify [
                  {"from": "flow-uuid", "to": "user-uuid", "type": "message.sent"}
                  {"from": "user-uuid", "to": "cred-uuid", "type": "message.received"}
                  {"from": "cred-uuid", "to": "cred-uuid", "type": "message.received"}
                ]
              json:
                metadata:
                  jobType: 'hello'
                data:
                  greeting: 'hola'
              auth:
                username: 'cred-uuid'
                password: 'cred-token'

            request.post '/v1/messages', options, (error, @response, @body) =>
              done error

          it 'should return a 404', ->
            expect(@response.statusCode).to.equal 404, JSON.stringify @body

      describe 'when we have a real credentials device', ->
        beforeEach ->
          serviceAuth = new Buffer('peter:i-could-eat').toString 'base64'
          @meshblu
            .post '/search/devices'
            .set 'Authorization', "Basic #{serviceAuth}"
            .set 'x-meshblu-as', 'cred-uuid'
            .send uuid: 'cred-uuid'
            .reply 200, [{
              uuid: 'cred-uuid'
              endoSignature: 'LebOB6aPRQJC7HuLqVqwBeZOFITW+S+jTExlXKrnhvcbzgn6b82fwyh0Qin8ccMym9y4ymIWcKunfa9bZj2YsA=='
              endo:
                authorizedKey: 'some-uuid'
                credentialsDeviceUuid: 'cred-uuid'
                encrypted: @encrypted
            }]

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

            request.post '/v1/messages', options, (error, @response, @body) =>
              done error

          it 'should return a 422', ->
            expect(@response.statusCode).to.equal 422, JSON.stringify(@body)

        describe 'when called with a valid message', ->
          beforeEach (done) ->
            @messageHandler.onMessage.yields null, metadata: {code: 200}, data: {whatever: 'this is a response'}
            @responseHandler = @meshblu
              .post '/messages'
              .set 'Authorization', "Basic #{@credentialsDeviceAuth}"
              .set 'x-meshblu-as', 'user-uuid'
              .send
                devices: ['flow-uuid']
                metadata:
                  code: 200
                  to: { foo: 'bar' }
                data:
                  whatever: 'this is a response'
              .reply 201

            options =
              baseUrl: "http://localhost:#{@serverPort}"
              headers:
                'x-meshblu-route': JSON.stringify [
                  {"from": "flow-uuid", "to": "user-uuid", "type": "message.sent"}
                  {"from": "user-uuid", "to": "cred-uuid", "type": "message.received"}
                  {"from": "cred-uuid", "to": "cred-uuid", "type": "message.received"}
                ]
              json:
                metadata:
                  jobType: 'hello'
                  respondTo: { foo: 'bar' }
                data:
                  greeting: 'hola'
              auth:
                username: 'cred-uuid'
                password: 'cred-token'

            request.post '/v1/messages', options, (error, @response, @body) =>
              done error

          it 'should return a 201', ->
            expect(@response.statusCode).to.equal 201, JSON.stringify @body

          it 'should respond to the message via meshblu', ->
            @responseHandler.done()

          it 'should call the hello messageHandler with the message and auth', ->
            expect(@messageHandler.onMessage).to.have.been.calledWith sinon.match {
              encrypted:
                secrets:
                  credentials:
                    secret: 'this is secret'
            }, {
              metadata:
                jobType: 'hello'
              data:
                greeting: 'hola'
            }

        describe 'when called with a valid message that was forwarded to the service device', ->
          beforeEach (done) ->
            @messageHandler.onMessage.yields null, metadata: {code: 200}, data: {whatever: 'this is a response'}
            @responseHandler = @meshblu
              .post '/messages'
              .set 'Authorization', "Basic #{@credentialsDeviceAuth}"
              .set 'x-meshblu-as', 'user-uuid'
              .send
                devices: ['flow-uuid']
                metadata:
                  code: 200
                  to: { foo: 'bar' }
                data:
                  whatever: 'this is a response'
              .reply 201

            options =
              baseUrl: "http://localhost:#{@serverPort}"
              headers:
                'x-meshblu-route': JSON.stringify [
                  {"from": "flow-uuid", "to": "user-uuid", "type": "message.sent"}
                  {"from": "user-uuid", "to": "cred-uuid", "type": "message.received"}
                  {"from": "cred-uuid", "to": "cred-uuid", "type": "message.received"}
                  {"from": "cred-uuid", "to": "peter", "type": "message.received"}
                  {"from": "peter", "to": "peter", "type": "message.received"}
                ]
              json:
                metadata:
                  jobType: 'hello'
                  respondTo: { foo: 'bar' }
                data:
                  greeting: 'hola'
              auth:
                username: 'cred-uuid'
                password: 'cred-token'

            request.post '/v1/messages', options, (error, @response, @body) =>
              done error

          it 'should return a 201', ->
            expect(@response.statusCode).to.equal 201, JSON.stringify @body

          it 'should respond to the message via meshblu', ->
            @responseHandler.done()

          it 'should call the hello messageHandler with the message and auth', ->
            expect(@messageHandler.onMessage).to.have.been.calledWith sinon.match {
              encrypted:
                secrets:
                  credentials:
                    secret: 'this is secret'
            }, {
              metadata:
                jobType: 'hello'
              data:
                greeting: 'hola'
            }

        describe 'when called with message that is a result of a user-uuid\'s subscription to itself', ->
          beforeEach (done) ->
            @messageHandler.onMessage.yields null, metadata: {code: 200}, data: {whatever: 'this is a response'}
            options =
              baseUrl: "http://localhost:#{@serverPort}"
              headers:
                'x-meshblu-route': JSON.stringify [
                  {"from": "flow-uuid", "to": "user-uuid", "type": "message.sent"}
                  {"from": "user-uuid", "to": "user-uuid", "type": "message.received"}
                  {"from": "user-uuid", "to": "cred-uuid", "type": "message.received"}
                  {"from": "cred-uuid", "to": "cred-uuid", "type": "message.received"}
                ]
              json:
                metadata:
                  jobType: 'hello'
                  respondTo: { foo: 'bar' }
                data:
                  greeting: 'hola'
              auth:
                username: 'cred-uuid'
                password: 'cred-token'

            request.post '/v1/messages', options, (error, @response, @body) =>
              done error

          it 'should return a 422', ->
            expect(@response.statusCode).to.equal 422


        describe "when called with a valid message that's the result of some other device's subscription to itself", ->
          beforeEach (done) ->
            @messageHandler.onMessage.yields null, metadata: {code: 200}, data: {whatever: 'this is a response'}
            @responseHandler = @meshblu
              .post '/messages'
              .set 'Authorization', "Basic #{@credentialsDeviceAuth}"
              .set 'x-meshblu-as', 'user-uuid'
              .send
                devices: ['whatever-uuid']
                metadata:
                  code: 200
                  to: { foo: 'bar' }
                data:
                  whatever: 'this is a response'
              .reply 201

            options =
              baseUrl: "http://localhost:#{@serverPort}"
              headers:
                'x-meshblu-route': JSON.stringify [
                  {"from": "whatever-uuid", "to": "whatever-uuid", "type": "message.received"}
                  {"from": "whatever-uuid", "to": "flow-uuid", "type": "message.received"}
                  {"from": "flow-uuid", "to": "user-uuid", "type": "message.received"}
                  {"from": "user-uuid", "to": "cred-uuid", "type": "message.received"}
                  {"from": "cred-uuid", "to": "cred-uuid", "type": "message.received"}
                ]
              json:
                metadata:
                  jobType: 'hello'
                  respondTo: { foo: 'bar' }
                data:
                  greeting: 'hola'
              auth:
                username: 'cred-uuid'
                password: 'cred-token'

            request.post '/v1/messages', options, (error, @response, @body) =>
              done error

          it 'should return a 201', ->
            expect(@response.statusCode).to.equal 201, JSON.stringify @body

        describe 'when called with a valid message, but theres an error', ->

          beforeEach 'Go back in time to 8am MST 2016-09-28 ', ->
            sinon.useFakeTimers moment('2016-09-28T15:00:00Z').valueOf()

          afterEach 'Back to the future', ->
            sinon.restore()

          beforeEach (done) ->
            @messageHandler.onMessage.yields new Error 'Something very bad happened'
            @responseHandler = @meshblu
              .post '/messages'
              .set 'Authorization', "Basic #{@credentialsDeviceAuth}"
              .set 'x-meshblu-as', 'user-uuid'
              .send
                devices: ['flow-uuid']
                metadata:
                  code: 500
                  to: 'food'
                  error:
                    message: 'Something very bad happened'
              .reply 201

            options =
              baseUrl: "http://localhost:#{@serverPort}"
              headers:
                'x-meshblu-route': JSON.stringify [
                  {"from": "flow-uuid", "to": "user-uuid", "type": "message.sent"}
                  {"from": "user-uuid", "to": "cred-uuid", "type": "message.received"}
                ]
              json:
                metadata:
                  jobType: 'hello'
                  respondTo: 'food'
                data:
                  greeting: 'hola'
              auth:
                username: 'cred-uuid'
                password: 'cred-token'

            @getUserDeviceHandler = @meshblu
              .get '/v2/devices/user-uuid'
              .set 'Authorization', "Basic #{@credentialsDeviceAuth}"
              .reply 200, statusDevice: 'status-device-uuid'

            @updateStatusDeviceHandler = @meshblu
              .put '/v2/devices/status-device-uuid'
              .set 'Authorization', "Basic #{@credentialsDeviceAuth}"
              .set 'x-meshblu-as', 'user-uuid'
              .send
                $set:
                  'status.errors':
                    $ref: '#/errors'
                $push:
                  errors:
                    $each: [
                      code: 500
                      message: 'Something very bad happened'
                      senderUuid: 'flow-uuid'
                      date: '2016-09-28T15:00:00Z'
                      metadata:
                        to: 'food'
                    ]
                    $slice: -99

              .reply 204

            request.post '/v1/messages', options, (error, @response, @body) =>
              done error

          it 'should call the onMessage messageHandler with the message and auth', ->
            expect(@messageHandler.onMessage).to.have.been.calledWith sinon.match {
              encrypted:
                secrets:
                  credentials:
                    secret: 'this is secret'
            }, {
              metadata:
                jobType: 'hello'
              data:
                greeting: 'hola'
            }

          it 'should return a 500', ->
            expect(@response.statusCode).to.equal 500, JSON.stringify @body

          it 'should respond to the message with the error via meshblu', ->
            @responseHandler.done()

          it 'should update the status device with the error', ->
            @updateStatusDeviceHandler.done()

        describe 'when called with a valid message, but the the endo is invalid', ->
          beforeEach (done) ->
            @messageHandler.onMessage.yields new Error 'Something very bad happened'
            @responseHandler = @meshblu
              .post '/messages'
              .set 'Authorization', "Basic #{@credentialsDeviceAuth}"
              .set 'x-meshblu-as', 'user-uuid'
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
                  {"from": "flow-uuid", "to": "user-uuid", "type": "message.sent"}
                  {"from": "user-uuid", "to": "cred-uuid", "type": "message.received"}
                ]
              json:
                metadata:
                  jobType: 'hello'
                data:
                  greeting: 'hola'
              auth:
                username: 'cred-uuid'
                password: 'cred-token'

            request.post '/v1/messages', options, (error, @response, @body) =>
              done error

          it 'should call the hello messageHandler with the message and auth', ->
            expect(@messageHandler.onMessage).to.have.been.calledWith sinon.match {
              metadata:
                jobType: 'hello'
              data:
                greeting: 'hola'
              encrypted:
                secrets:
                  credentials:
                    secret: 'this is secret'
            }

          it 'should return a 500', ->
            expect(@response.statusCode).to.equal 500, JSON.stringify @body

          it 'should respond to the message with the error via meshblu', ->
            @responseHandler.done()
