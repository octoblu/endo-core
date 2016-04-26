_               = require 'lodash'
MeshbluConfig   = require 'meshblu-config'
PassportOctoblu = require 'passport-octoblu'

class OctobluStrategy extends PassportOctoblu
  constructor: (env) ->
    throw new Error('Missing required environment variable: MESHBLU_UUID')  if _.isEmpty process.env.MESHBLU_UUID
    throw new Error('Missing required environment variable: MESHBLU_TOKEN') if _.isEmpty process.env.MESHBLU_TOKEN
    throw new Error('Missing required environment variable: ENDO_OCTOBLU_OAUTH_URL') if _.isEmpty process.env.ENDO_OCTOBLU_OAUTH_URL

    options = {
      clientID:         process.env.MESHBLU_UUID
      clientSecret:     process.env.MESHBLU_TOKEN
      authorizationURL: "#{process.env.ENDO_OCTOBLU_OAUTH_URL}/authorize"
      tokenURL:         "#{process.env.ENDO_OCTOBLU_OAUTH_URL}/access_token"
      meshbluConfig:    new MeshbluConfig().toJSON()
    }

    super options, (bearerToken, secret, {uuid}, next) =>
      next null, {uuid, bearerToken}

module.exports = OctobluStrategy
