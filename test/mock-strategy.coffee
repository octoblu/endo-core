_ = require 'lodash'
passport = require 'passport-strategy'

class MockStrategy extends passport.Strategy
  constructor: ({@name}, @verifier) ->
    super

  authenticate: (req, options) -> # keep this guy skinny
    @verifier req, (error, user) => # keep this guy fat
      return @fail message: error.message, 302 if error?
      return @success user

module.exports = MockStrategy
