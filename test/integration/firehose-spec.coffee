{afterEach, beforeEach, describe, it} = global
{expect} = require 'chai'
sinon    = require 'sinon'

fs            = require 'fs'
request       = require 'request'
URL           = require 'url'
Encryption    = require 'meshblu-encryption'
enableDestroy = require 'server-destroy'
shmock        = require 'shmock'
SocketIO      = require 'socket.io'
MockStrategy  = require '../mock-strategy'
Endo          = require '../..'

xdescribe 'firehose', ->
  beforeEach 'setup socket.io', ->
    @firehoseServer = new SocketIO 0xcaf1

  afterEach ->
    @firehoseServer.close()

  beforeEach 'setup meshblu http', ->
    @serviceAuth = new Buffer('peter:i-could-eat').toString 'base64'
    @privateKey = fs.readFileSync "#{__dirname}/../data/private-key.pem", 'utf8'

    @encryption = Encryption.fromPem @privateKey
    @publicKey = @encryption.key.exportKey 'public'

    @meshblu = shmock 0xd00d
    enableDestroy @meshblu
    @messageHandler = onMessage: sinon.stub()
    @meshblu
      .get '/v2/whoami'
      .set 'Authorization', "Basic #{@serviceAuth}"
      .reply 200, {
        options:
          imageUrl: "http://this-is-an-image.exe"
      }

    @meshblu
      .get '/publickey'
      .reply 200, {@publicKey}

  afterEach (done) ->
    @meshblu.destroy done

  beforeEach 'setup sut', ->
    options =
      logFn: ->
      messageHandler: @messageHandler
      serviceUrl: 'http://octoblu.xxx'
      deviceType: 'endo-endor'
      skipExpress: true
      useFirehose: true
      meshbluConfig:
        hostname: 'localhost'
        protocol: 'http'
        port: 0xd00d
        uuid: 'peter'
        token: 'i-could-eat'
        privateKey: @privateKey
      firehoseMeshbluConfig:
        hostname: 'localhost'
        protocol: 'http'
        port: 0xcaf1
        uuid: 'peter'
        token: 'i-could-eat'
        privateKey: @privateKey

    @sut = new Endo options

    afterEach (done) ->
      @sut.stop done

  describe '->run', ->
    beforeEach (done) ->
      @firehoseServer.on 'connection', (@socket) =>
        {@pathname, @query} = URL.parse @socket.client.request.url, true
        @uuid = @socket.client.request.headers['x-meshblu-uuid']
        @token = @socket.client.request.headers['x-meshblu-token']
        done()

      @sut.run =>

    it 'should connect', ->
      expect(@socket).to.exist
      expect(@pathname).to.equal '/socket.io/v1/peter/'

    it 'should pass along the auth info', ->
      expect(@uuid).to.equal 'peter'
      expect(@token).to.equal 'i-could-eat'
      expect(@query.uuid).to.equal 'peter'
      expect(@query.token).to.equal 'i-could-eat'
