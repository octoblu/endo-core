class OctobluAuthController
  storeAuthAndRedirect: (req, res) =>
    res.cookie('meshblu_auth_bearer', req.user.bearerToken)
    res.redirect '/auth/api'

  invalidPassport: (req, res) =>
    req.status(500).send 'Invalid passport library. Passport must redirect to "/auth/api/callback" when authentication is successful'

module.exports = OctobluAuthController
