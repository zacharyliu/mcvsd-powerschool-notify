https = require 'https'
querystring = require 'querystring'
cheerio = require 'cheerio'

# Import PowerSchool md5.js login scripts
eval(require('fs').readFileSync(__dirname + '/md5.js', 'utf8'));

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
    @paths =
      main: '/guardian/home.html'

  get: (path, callback) ->
    options =
      host: 'mcvsd.powerschool.com'
      path: path
      headers:
        cookie: @cookie
    req = https.request options, (res) ->
      html = ''
      res.on 'data', (data) ->
        html += data
      res.on 'end', () ->
        callback html
    req.end()

  $get: (path, callback) ->
    @get path, (data) =>
      $ = cheerio.load data
      callback $

  list: (callback) ->
    instance = @
    @$get @paths.main, ($) ->
      list = []
      $('#quickLookup table:first-child tr[bgcolor!=""]').each (i) ->
        item = {}

        item.schedule = $(@).find('td:first-child').text()

        item.title = $(@).find('td[align="left"]').clone().remove('br').remove('a').text()[0...-2]

        teacher_items = $(@).find('td[align="left"]').find('a').eq(1).text().split(', ').reverse()
        item.teacher =
          name: teacher_items.join(' ')
          first_name: teacher_items[0]
          last_name: teacher_items[1]

        MPs =
          Q1: 12
          Q2: 13
          Q3: 14
          Q4: 15
          M1: 16
          F1: 17
          Y1: 18
        item.grades = {}
        item.paths = {}
        for MP, eq of MPs
          grade = $(@).find('td').eq(eq).text()
          path = $(@).find('td').eq(eq).find('a').attr('href')
          if path?
            path = '/guardian/' + path
          else
            path = undefined
          item.grades[MP] = grade
          item.paths[MP] = path

        id_elem = $(@).find('td').eq(18).find('a').attr('href')
        if id_elem?
          item.id = id_elem.match(/\?frn=(\d+)&/)[1]

        item.get = (mp, callback) ->
          if not item.paths[mp]?
            throw new Error("No data exists for " + mp)
          else
            instance.$get item.paths[mp], ($) ->
              output =
                rows: []
                last_updated: new Date $('#legend').find('p').eq(0).text().match(/on (.*)$/)[1]

              $('table[align="center"] tr[bgcolor!=""]').each ->
                item = {}
                
                item.due_date = new Date $(@).find('td').eq(0).text()
                item.category = $(@).find('td').eq(1).text()
                item.assignment = $(@).find('td').eq(2).text()
                score = $(@).find('td').eq(8).text().split('/')
                item.score = [parseFloat score[0], parseFloat score[1]]
                item.percent = parseFloat $(@).find('td').eq(9).text()
                
                output.rows.push(item)

              callback output

        list.push item
      callback list
