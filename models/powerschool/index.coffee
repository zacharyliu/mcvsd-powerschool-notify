https = require 'https'
querystring = require 'querystring'
jsdom = require('jsdom')

# Import PowerSchool md5.js login scripts
eval(require('fs').readFileSync('./md5.js', 'utf8'));

connect = (username, password, callback) ->
  https.get 'https://mcvsd.powerschool.com/public/', (res) ->
    html = ""
    res.on 'data', (data) ->
      html += data
    res.on 'end', () ->
      # Specify value for pskey
      pskey = html.match(/var pskey = "([^"']+)"/)[1]

      # Process passwords
      originalpw = password
      b64pw = b64_md5(originalpw)
      hmac_md5pw = hex_hmac_md5(pskey, b64pw)
      pw = hmac_md5pw
      dbpw = hex_hmac_md5(pskey, originalpw.toLowerCase())

      # Prepare data object
      data =
        pstoken: html.match(/name="pstoken" value="([^"']+)"/)[1]
        contextData: html.match(/name="contextData" value="([^"']+)"/)[1]
        dbpw: dbpw
        credentialType: "User Id and Password Credential"
        account: username
        pw: pw
      post_data = querystring.stringify data

      # Prepare options object
      options =
        host: 'mcvsd.powerschool.com'
        path: '/guardian/home.html'
        method: 'POST'
        headers:
          'Content-Type': 'application/x-www-form-urlencoded'
          'Content-Length': post_data.length

      post_req = https.request options, (post_res) ->
        if post_res.statusCode is 200
          throw new Error("Incorrect username or password.")
        else
          # Retrieve the cookie
          cookie = post_res.headers['set-cookie'][0]

          callback new ps_model cookie

      post_req.write post_data
      post_req.end()

exports.connect = connect

class ps_model
  constructor: (@cookie) ->

  get_raw: (path, callback) ->
    options =
      host: 'mcvsd.powerschool.com'
      path: path
      headers:
        cookie: @cookie
    https.request options, (res) ->
      html = ''
      res.on 'data', (data) ->
        html += data
      res.on 'end', () ->
        callback html

  get: (path, callback) ->
    @get_raw path, (data) =>
      jsdom.env {
        html: data
        scripts: ['jquery-1.8.2.min.js']
      }, (err, window) =>
        $ = window.jQuery
        callback $

try
  connect 'chiungyin', 'j9m3n8m3', (ps) ->
    console.log ps
    ps.get_raw '/guardian/home.html', (data) ->
      console.log data
catch e
  console.log "Error"
