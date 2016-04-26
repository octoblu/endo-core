_               = require 'lodash'
PassportOctoblu = require 'passport-octoblu'

MISSING_MESHBLU_UUID  = 'Missing required environment variable: MESHBLU_UUID'
MISSING_MESHBLU_TOKEN = 'Missing required environment variable: MESHBLU_TOKEN'
MISSING_OAUTH_URL     = 'Missing required environment variable: ENDO_OCTOBLU_OAUTH_URL'

class OctobluStrategy extends PassportOctoblu
  constructor: (env, meshbluConfig) ->
    throw new Error MISSING_MESHBLU_UUID  if _.isEmpty process.env.MESHBLU_UUID
    throw new Error MISSING_MESHBLU_TOKEN if _.isEmpty process.env.MESHBLU_TOKEN
    throw new Error MISSING_OAUTH_URL     if _.isEmpty process.env.ENDO_OCTOBLU_OAUTH_URL

    options = {
      clientID:         process.env.MESHBLU_UUID
      clientSecret:     process.env.MESHBLU_TOKEN
      authorizationURL: "#{process.env.ENDO_OCTOBLU_OAUTH_URL}/authorize"
      tokenURL:         "#{process.env.ENDO_OCTOBLU_OAUTH_URL}/access_token"
      meshbluConfig:    meshbluConfig
    }

    super options, (bearerToken, secret, {uuid}, next) =>
      next null, {uuid, bearerToken}

module.exports = OctobluStrategy
