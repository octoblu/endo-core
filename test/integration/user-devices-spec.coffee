_ = require 'lodash'
fs           = require 'fs'
http         = require 'http'
request      = require 'request'
shmock       = require '@octoblu/shmock'
MockStrategy = require '../mock-strategy'
Server       = require '../../src/server'

describe 'Sample Spec', ->
  beforeEach (done) ->
    @meshblu = shmock 0xd00d

    @apiStrategy = new MockStrategy name: 'github'
    @octobluStrategy = new MockStrategy name: 'octoblu'

    serverOptions =
      logFn: ->
      messageHandlers: {}
      port: undefined,
      disableLogging: true
      apiStrategy: @apiStrategy
      deviceType: 'endo-github'
      octobluStrategy: @octobluStrategy
      serviceUrl: 'http://octoblu.xxx'
      meshbluConfig:
        server: 'localhost'
        port: 0xd00d
        uuid: 'peter'
        token: 'i-could-eat'
        privateKey: @privateKey

    @meshblu
      .get '/v2/whoami'
      .set 'Authorization', "Basic cGV0ZXI6aS1jb3VsZC1lYXQ="
      .reply 200, {
        options:
          imageUrl: "http://this-is-an-image.exe"
      }

    @server = new Server serverOptions

    @server.run (error) =>
      return done error if error?
      @serverPort = @server.address().port
      done()

  afterEach (done) ->
    @server.stop done

  afterEach (done) ->
    @meshblu.close done

  describe 'On GET /cred-uuid/user-devices', ->
    describe 'when authorized', ->
      beforeEach (done) ->
        userAuth = new Buffer('some-uuid:some-token').toString 'base64'
        serviceAuth = new Buffer('peter:i-could-eat').toString 'base64'
        credentialsDeviceAuth = new Buffer('cred-uuid:cred-token2').toString 'base64'

        @meshblu
          .get '/v2/whoami'
          .set 'Authorization', "Basic #{userAuth}"
          .reply 200, uuid: 'some-uuid', token: 'some-token'

        @meshblu
          .post '/search/devices'
          .send uuid: 'cred-uuid', 'endo.authorizedUuid': 'some-uuid'
          .set 'Authorization', "Basic #{serviceAuth}"
          .reply 200, uuid: 'cred-uuid', endo: {authorizedUuid: 'some-uuid'}

        @meshblu
          .post '/devices/cred-uuid/tokens'
          .set 'Authorization', "Basic #{serviceAuth}"
          .reply 200, uuid: 'cred-uuid', token: 'cred-token2'

        @meshblu
          .get '/v2/devices/cred-uuid/subscriptions'
          .set 'Authorization', "Basic #{credentialsDeviceAuth}"
          .reply 200, [
            {emitterUuid: 'first-user-uuid', type: 'message.received'}
            {emitterUuid: 'second-user-uuid',type: 'message.received'}
            {emitterUuid: 'whatever-user-uuid', type: 'message.sent'}
          ]

        options =
          baseUrl: "http://localhost:#{@serverPort}"
          json: true
          auth:
            username: 'some-uuid'
            password: 'some-token'

        request.get '/cred-uuid/user-devices', options, (error, @response, @body) =>
          done error

      it 'should return a 200', ->
        expect(@response.statusCode).to.equal 200

      it 'should return the list of user devices', ->
        expect(@body).to.deep.equal [
          {uuid: 'first-user-uuid'}
          {uuid: 'second-user-uuid'}
        ]

    describe 'when inauthentic', ->
      beforeEach (done) ->
        userAuth = new Buffer('some-uuid:some-token').toString 'base64'
        serviceAuth = new Buffer('peter:i-could-eat').toString 'base64'
        credentialsDeviceAuth = new Buffer('cred-uuid:cred-token2').toString 'base64'

        @meshblu
          .get '/v2/whoami'
          .set 'Authorization', "Basic #{userAuth}"
          .reply 200, uuid: 'some-uuid', token: 'some-token'

        @meshblu
          .post '/search/devices'
          .send uuid: 'cred-uuid', 'endo.authorizedUuid': 'some-uuid'
          .set 'Authorization', "Basic #{serviceAuth}"
          .reply 200, []

        @meshblu
          .post '/devices/cred-uuid/tokens'
          .set 'Authorization', "Basic #{serviceAuth}"
          .reply 200, uuid: 'cred-uuid', token: 'cred-token2'

        @meshblu
          .get '/v2/devices/cred-uuid/subscriptions'
          .set 'Authorization', "Basic #{credentialsDeviceAuth}"
          .reply 200, [
            {uuid: 'first-user-uuid', type: 'message.received'}
            {uuid: 'second-user-uuid',type: 'message.received'}
            {uuid: 'whatever-user-uuid', type: 'message.sent'}
          ]

        options =
          baseUrl: "http://localhost:#{@serverPort}"
          json: true
          auth:
            username: 'some-uuid'
            password: 'some-token'

        request.get '/cred-uuid/user-devices', options, (error, @response, @body) =>
          done error

      it 'should return a 403', ->
        expect(@response.statusCode).to.equal 403

  describe 'On POST /cred-uuid/user-devices', ->
    describe 'when authorized', ->
      beforeEach (done) ->
        userAuth = new Buffer('some-uuid:some-token').toString 'base64'
        serviceAuth = new Buffer('peter:i-could-eat').toString 'base64'
        credentialsDeviceAuth = new Buffer('cred-uuid:cred-token2').toString 'base64'

        @meshblu
          .get '/v2/whoami'
          .set 'Authorization', "Basic #{userAuth}"
          .reply 200, uuid: 'some-uuid', token: 'some-token'

        @meshblu
          .post '/search/devices'
          .send uuid: 'cred-uuid', 'endo.authorizedUuid': 'some-uuid'
          .set 'Authorization', "Basic #{serviceAuth}"
          .reply 200, uuid: 'cred-uuid', endo: {authorizedUuid: 'some-uuid'}

        @meshblu
          .post '/devices/cred-uuid/tokens'
          .set 'Authorization', "Basic #{serviceAuth}"
          .reply 200, uuid: 'cred-uuid', token: 'cred-token2'


        @createUserDevice = @meshblu
          .post '/devices'
          .send
            type: "endo-github"
            imageUrl: "http://this-is-an-image.exe"
            octoblu:
              flow:
                forwardMetadata: true
            meshblu:
              version: '2.0.0'
              whitelists:
                broadcast:
                  as: [{uuid: 'some-uuid'}]
                  received: [{uuid: 'some-uuid'}]
                  sent: [{uuid: 'some-uuid'}]
                configure:
                  as: [{uuid: 'some-uuid'}]
                  received: [{uuid: 'some-uuid'}]
                  sent: [{uuid: 'some-uuid'}]
                  update: [{uuid: 'some-uuid'}]
                discover:
                  view: [{uuid: 'some-uuid'}]
                  as: [{uuid: 'some-uuid'}]
                message:
                  as: [{uuid: 'some-uuid'}, {uuid: 'cred-uuid'}]
                  received: [{uuid: 'some-uuid'}, {uuid: 'cred-uuid'}]
                  sent: [{uuid: 'some-uuid'}]
                  from: [{uuid: 'some-uuid'}]
          .reply 201, uuid: 'user-device-uuid', token: 'user-device-token'

        @createMessageReceivedSubscription = @meshblu
          .post '/v2/devices/cred-uuid/subscriptions/user-device-uuid/message.received'
          .set 'Authorization', "Basic #{credentialsDeviceAuth}"
          .reply 201

        options =
          baseUrl: "http://localhost:#{@serverPort}"
          json: true
          headers:
            Authorization: "Bearer #{userAuth}"

        request.post '/cred-uuid/user-devices', options, (error, @response, @body) =>
          done error

      it 'should create the user device', ->
        @createUserDevice.done()

      it "should subscribe the credentials-device to the user device's received messages", ->
        @createMessageReceivedSubscription.done()

      it 'should return a 201', ->
        expect(@response.statusCode).to.equal 201

      it 'should return the user device', ->
        expect(@body).to.deep.equal uuid: 'user-device-uuid', token: 'user-device-token'
