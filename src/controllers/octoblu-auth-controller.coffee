class OctobluAuthController
  storeAuthAndRedirect: (req, res) =>
    res.cookie('meshblu_auth_bearer', req.user.bearerToken)
    res.redirect '/auth/api'

module.exports = OctobluAuthController
