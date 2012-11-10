index = require('./routes/index')
user = require('./routes/user')

routes =
  '/': index.index
  '/users': user.index

module.exports = (app) ->
  for path, route of routes
    app.get path, route
