_ = require 'lodash'
fs           = require 'fs'
http         = require 'http'
request      = require 'request'
shmock       = require '@octoblu/shmock'
MockStrategy = require '../mock-strategy'
Server       = require '../../src/server'
path         = require 'path'
Encryption   = require 'meshblu-encryption'

describe 'User Devices Spec', ->
  beforeEach (done) ->
    @meshblu = shmock 0xd00d
    @privateKey = fs.readFileSync "#{__dirname}/../data/private-key.pem", 'utf8'

    encryption = Encryption.fromPem @privateKey
    @encryptedSecrets = encryption.encrypt 'this is secret'

    @apiStrategy = new MockStrategy name: 'lib'
    @octobluStrategy = new MockStrategy name: 'octoblu'

    serverOptions =
      logFn: ->
      messageHandlers: {}
      port: undefined,
      disableLogging: true
      apiStrategy: @apiStrategy
      apiName: 'github'
      deviceType: 'endo-core'
      octobluStrategy: @octobluStrategy
      serviceUrl: 'http://octoblu.xxx'
      meshbluConfig:
        server: 'localhost'
        port: 0xd00d
        uuid: 'peter'
        token: 'i-could-eat'
        privateKey: @privateKey
      schemas:
        hello:   require '../data/schemas/hello-schema.json'
        namaste: require '../data/schemas/namaste-schema.json'
      userDeviceManagerUrl: 'http://manage-my.endo'

    @meshblu
      .get '/v2/whoami'
      .set 'Authorization', "Basic cGV0ZXI6aS1jb3VsZC1lYXQ="
      .reply 200, {
        options:
          imageUrl: "http://this-is-an-image.exe"
          resourceOwnerName: 'resource owner name'
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
          .send uuid: 'cred-uuid', 'endo.authorizedKey': "pG7eYd4TYZOX2R5S73jo9aexPzldiNo4pw1wViDpYrAAGRMT6dY0jlbXbfHMz9y+El6AcXMZJEOxaeO1lITsYg=="
          .set 'Authorization', "Basic #{serviceAuth}"
          .reply 200, [
            uuid: 'cred-uuid'
            endoSignature: 'Mj7Tm10Ml/Sg5YTSOlqgsWZbkg3ELZg0ivY0mkRdgSz5tB0IXFJR2cYIBq0PnV3ke6h4HxNtK6HCseXVB7khMw=='
            endo:
              authorizedKey: 'some-uuid'
              credentialsDeviceUuid: 'cred-uuid'
              secrets: @encryptedSecrets
          ]

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
            {emitterUuid: 'cred-uuid', type: 'message.received'}
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
          .send uuid: 'cred-uuid', 'endo.authorizedKey': 'pG7eYd4TYZOX2R5S73jo9aexPzldiNo4pw1wViDpYrAAGRMT6dY0jlbXbfHMz9y+El6AcXMZJEOxaeO1lITsYg=='
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

      it 'should return a 404', ->
        expect(@response.statusCode).to.equal 404

    describe 'when authorized, but with a bad credentials device', ->
      beforeEach (done) ->
        userAuth = new Buffer('some-uuid:some-token').toString 'base64'
        serviceAuth = new Buffer('peter:i-could-eat').toString 'base64'

        @meshblu
          .get '/v2/whoami'
          .set 'Authorization', "Basic #{userAuth}"
          .reply 200, uuid: 'some-uuid', token: 'some-token'

        @meshblu
          .post '/search/devices'
          .send uuid: 'bad-cred-uuid', 'endo.authorizedKey': "pG7eYd4TYZOX2R5S73jo9aexPzldiNo4pw1wViDpYrAAGRMT6dY0jlbXbfHMz9y+El6AcXMZJEOxaeO1lITsYg=="
          .set 'Authorization', "Basic #{serviceAuth}"
          .reply 200, [
            uuid: 'bad-cred-uuid'
            endo:
              authorizedKey: 'some-uuid'
              credentialsDeviceUuid: 'cred-uuid'
              secrets: @encryptedSecrets
          ]

        options =
          baseUrl: "http://localhost:#{@serverPort}"
          json: true
          auth:
            username: 'some-uuid'
            password: 'some-token'

        request.get '/bad-cred-uuid/user-devices', options, (error, @response, @body) =>
          done error

      it 'should return a 404', ->
        expect(@response.statusCode).to.equal 404, JSON.stringify @body

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
          .send uuid: 'cred-uuid', 'endo.authorizedKey': 'pG7eYd4TYZOX2R5S73jo9aexPzldiNo4pw1wViDpYrAAGRMT6dY0jlbXbfHMz9y+El6AcXMZJEOxaeO1lITsYg=='
          .set 'Authorization', "Basic #{serviceAuth}"
          .reply 200, [
            uuid: 'cred-uuid'
            endoSignature: 'dm8MT1FARvJ1RInXlqDtLCylCDIc3YD6fgWewwccaCCmoijuctJY2sGIf6MFmszjUDx2PXGMygU6rlwdwcapxw='
            endo:
              credentialsDeviceUuid: 'cred-uuid'
              secrets: @encryptedSecrets
          ]

        @meshblu
          .post '/devices/cred-uuid/tokens'
          .set 'Authorization', "Basic #{serviceAuth}"
          .reply 200, uuid: 'cred-uuid', token: 'cred-token2'

        @createUserDevice = @meshblu
          .post '/devices'
          .send
            type: "endo-core"
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
          .reply 201, uuid: 'user_device_uuid', token: 'user_device_token'

        @createMessageReceivedSubscription = @meshblu
          .post '/v2/devices/cred-uuid/subscriptions/user_device_uuid/message.received'
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
        expect(@body).to.deep.equal uuid: 'user_device_uuid', token: 'user_device_token'

  describe 'On DELETE /cred-uuid/user-devices/user_device_uuid', ->
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
          .send uuid: 'cred-uuid', 'endo.authorizedKey': 'pG7eYd4TYZOX2R5S73jo9aexPzldiNo4pw1wViDpYrAAGRMT6dY0jlbXbfHMz9y+El6AcXMZJEOxaeO1lITsYg=='
          .set 'Authorization', "Basic #{serviceAuth}"
          .reply 200, [
            uuid: 'cred-uuid'
            endoSignature: 'dm8MT1FARvJ1RInXlqDtLCylCDIc3YD6fgWewwccaCCmoijuctJY2sGIf6MFmszjUDx2PXGMygU6rlwdwcapxw='
            endo:
              credentialsDeviceUuid: 'cred-uuid'
              secrets: @encryptedSecrets
          ]

        @meshblu
          .post '/devices/cred-uuid/tokens'
          .set 'Authorization', "Basic #{serviceAuth}"
          .reply 200, uuid: 'cred-uuid', token: 'cred-token2'

        @deleteMessageReceivedSubscription = @meshblu
          .delete '/v2/devices/cred-uuid/subscriptions/user_device_uuid/message.received'
          .set 'Authorization', "Basic #{credentialsDeviceAuth}"
          .reply 201

        options =
          baseUrl: "http://localhost:#{@serverPort}"
          json: true
          headers:
            Authorization: "Bearer #{userAuth}"

        request.delete '/cred-uuid/user-devices/user_device_uuid', options, (error, @response, @body) =>
          done error

      it "should delete the subscription from the credentials-device to the user device's received messages", ->
        @deleteMessageReceivedSubscription.done()

      it 'should return a 204', ->
        expect(@response.statusCode).to.equal 204

      it 'should return nothing', ->
        expect(@body).to.be.empty

  describe 'On DELETE /cred-uuid/user-devices/cred-uuid', ->
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
          .send uuid: 'cred-uuid', 'endo.authorizedKey': 'pG7eYd4TYZOX2R5S73jo9aexPzldiNo4pw1wViDpYrAAGRMT6dY0jlbXbfHMz9y+El6AcXMZJEOxaeO1lITsYg=='
          .set 'Authorization', "Basic #{serviceAuth}"
          .reply 200, [
            uuid: 'cred-uuid'
            endoSignature: 'dm8MT1FARvJ1RInXlqDtLCylCDIc3YD6fgWewwccaCCmoijuctJY2sGIf6MFmszjUDx2PXGMygU6rlwdwcapxw='
            endo:
              credentialsDeviceUuid: 'cred-uuid'
              secrets: @encryptedSecrets
          ]

        @meshblu
          .post '/devices/cred-uuid/tokens'
          .set 'Authorization', "Basic #{serviceAuth}"
          .reply 200, uuid: 'cred-uuid', token: 'cred-token2'

        options =
          baseUrl: "http://localhost:#{@serverPort}"
          json: true
          headers:
            Authorization: "Bearer #{userAuth}"

        request.delete '/cred-uuid/user-devices/cred-uuid', options, (error, @response, @body) =>
          done error

      it 'should return a 403', ->
        expect(@response.statusCode).to.equal 403, JSON.stringify @body
