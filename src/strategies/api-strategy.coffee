_ = require 'lodash'
PassportLib = require 'passport-lib'

class LibStrategy extends PassportLib
  constructor: (env) ->
    throw new Error('Missing required environment variable: ENDO_LIB_LIB_CLIENT_ID')     if _.isEmpty process.env.ENDO_LIB_LIB_CLIENT_ID
    throw new Error('Missing required environment variable: ENDO_LIB_LIB_CLIENT_SECRET') if _.isEmpty process.env.ENDO_LIB_LIB_CLIENT_SECRET
    throw new Error('Missing required environment variable: ENDO_LIB_LIB_CALLBACK_URL')  if _.isEmpty process.env.ENDO_LIB_LIB_CALLBACK_URL

    options = {
      clientID:     process.env.ENDO_LIB_LIB_CLIENT_ID
      clientSecret: process.env.ENDO_LIB_LIB_CLIENT_SECRET
      callbackUrl:  process.env.ENDO_LIB_LIB_CALLBACK_URL
    }

    super options, @onAuthorization

  onAuthorization: (accessToken, refreshToken, profile, callback) =>
    callback null, {
      resourceOwnerID: profile.id
      resourceOwnerSecrets:
        secret: accessToken
        refreshToken: refreshToken
    }

module.exports = LibStrategy
