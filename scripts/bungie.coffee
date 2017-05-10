require('dotenv').load()
Deferred = require('promise.coffee').Deferred
Q = require('q')
DataHelper = require './bungie-data-helper.coffee'
constants = require './constants.coffee'

dataHelper = new DataHelper
helpText = "Use the `help` command to learn about using the bot, or check out the full README here: https://github.com/RuCray/destiny_weekly_update"

module.exports = (robot) ->
  # executes when any text is directed at the bot
  robot.respond /(.*)/i, (res) ->
    if /help/i.test(res.match[1])
      return

    array = res.match[1].split ' '

    # trims spaces and removes empty elements in array
    input = []
    input.push el.trim() for el in array when (el.trim() isnt "")

    if input.length > 3
      message = "Something didn't look right... #{helpText}"
      sendError(robot, res, message)
      return

    data = {}

    # activity should always be last input
    el = input[input.length-1].toLowerCase()
    activityKey = constants.ACTIVITY_KEYS[el]
    if !activityKey
      message = "Available commands are:\n"
      for command in constants.COMMANDS
        message += "`#{command}`\n"
      message += "\n#{helpText}"
      sendError(robot, res, message)
      return
    else
      data['activityKey'] = activityKey

    getPublicWeeklyActivity(res, data.activityKey).then (activityDetails) ->

      payload =
        message: res.message
        attachments: [dataHelper.parseActivityDetails(activityDetails)]

      robot.emit 'slack-attachment', payload

    # # interprets input based on length
    # # if 3 elements, assume: gamertag, network, bucket
    # if input.length is 3
    #   el = input[1].toLowerCase()
    #   data['membershipType'] = checkNetwork(el)
    #   data['displayName'] = input[0]
    # else if input.length is 2
    #   el = input[0].toLowerCase()
    #   data['membershipType'] = checkNetwork(el)
    #   if data['membershipType'] is null
    #     # assume first input was gamertag
    #     data['displayName'] = input[0]
    #   else
    #     # assume gamertag not provided, use slack first name
    #     data['displayName'] = res.message.user.slack.profile.first_name
    # else if input.length is 1
    #   # assume only bucket was provided
    #   data['membershipType'] = null
    #   data['displayName'] = res.message.user.slack.profile.first_name
    # else
    #   # catch all, but should never happen...
    #   message = "Something didn't look right... #{helpText}"
    #   sendError(robot, res, message)
    #   return

    # tryPlayerId(res, data.membershipType, data.displayName, robot).then (player) ->
    #   getCharacterId(res, player.platform, player.membershipId, robot).then (characterId) ->
    #     getItemIdFromSummary(res, player.platform, player.membershipId, characterId, data.bucket, robot).then (itemInstanceId) ->
    #       getItemDetails(res, player.platform, player.membershipId, characterId, itemInstanceId).then (item) ->
    #         parsedItem = dataHelper.parseItemAttachment(item)

    #         payload =
    #           message: res.message
    #           attachments: parsedItem

    #         robot.emit 'slack-attachment', payload


  robot.respond /help/i, (res) ->
    sendHelp(robot, res)

  robot.respond /!help/i, (res) ->
    sendHelp(robot, res)


sendHelp = (robot, res) ->
  admin = process.env.ADMIN_USERNAME
  if admin
    admin_message = "\nFeel free to message me (@#{admin}) with any other questions about the bot."
  else
    admin_message = ""

  # customizes help message depending on display options
  options = "weapon/armor"
  example1 = "primary"
  example2 = "helmet"
  example3 = "special"

  mdText = "To show off your #{options}, message the bot with your gamertag, network, and #{options} activity, separated by spaces.
  The bot will always look at the *most recently played character* on your account.
  The standard usage looks like this: \n```@gunsmithbot: MyGamerTag xbox #{example1}```\n
  If you've set up your slack profile so that your *first name* matches your gamertag, you can omit this:```@gunsmithbot: playstation #{example2}```\n
  If your gamertag only exists on one network, that can be omitted as well:```@gunsmithbot: #{example3}```\n
  *Special note to Xbox Users:*\n If your gamertag has any spaces in it, these will need to be substituted with underscores (\"_\")
  in order for the bot to recognize the input properly.
  This is only required when inputting the gamertag manually however; spaces are fine in your slack first name.#{admin_message}\n\n
  _Keep that thing oiled, guardian._"
  fallback = "To show off your #{options}, message the bot with your gamertag, network, and #{options} activity, separated by spaces.
  The bot will always look at the *most recently played character* on your account.
  The standard usage looks like this: \n\"@gunsmithbot: MyGamerTag xbox #{example1}\"\n
  If you've set up your slack profile so that your FIRST NAME matches your gamertag, you can omit this:\"@gunsmithbot: playstation #{example2}\"\n
  If your gamertag only exists on one network, that can be omitted as well: \"@gunsmithbot: #{example3}\"\n
  SPECIAL NOTE TO XBOX USERS:\n If your gamertag has any spaces in it, these will need to be substituted with underscores (\"_\")
  in order for the bot to recognize the input properly.
  This is only required when inputting the gamertag manually however; spaces are fine in your slack first name.#{admin_message}\n\n
  Keep that thing oiled, guardian."

  attachment =
    title: "Using the Gunsmith Bot"
    title_link: "https://github.com/RuCray/destiny_weekly_update"
    text: mdText
    fallback: fallback
    mrkdwn_in: ["text"]
  payload =
    message: res.message
    attachments: attachment

  robot.emit 'slack-attachment', payload


checkNetwork = (network) ->
  xbox = ['xbox', 'xb1', 'xbox1', 'xboxone', 'xbox360', 'xb360', 'xbone', 'xb']
  playstation = ['playstation', 'ps', 'ps3', 'ps4', 'playstation3', 'playstation4']
  if network in xbox
    return '1'
  else if network in playstation
    return '2'
  else
    return null

# Sends error message as DM in slack
sendError = (robot, res, message) ->
  robot.send {room: res.message.user.name, "unfurl_media": false}, message

tryPlayerId = (res, membershipType, displayName, robot) ->
  deferred = new Deferred()

  if membershipType
    networkName = if membershipType is '1' then 'xbox' else 'playstation'
    # replaces underscores with spaces (for xbox)
    displayName = displayName.split('_').join(' ') if networkName is 'xbox'

    return getPlayerId(res, membershipType, displayName, robot)
    .then (results) ->
      if !results
        robot.send {room: res.message.user.name, "unfurl_media": false}, "Could not find guardian with name: #{displayName} on #{networkName}. #{helpText}"
        deferred.reject()
        return
      deferred.resolve({platform: membershipType, membershipId: results})
      deferred.promise
  else
    return Q.all([
      getPlayerId(res, '1', displayName.split('_').join(' '), robot),
      getPlayerId(res, '2', displayName, robot)
    ]).then (results) ->
      if results[0] && results[1]
        robot.send {room: res.message.user.name, "unfurl_media": false}, "Mutiple platforms found for: #{displayName}. use \"xbox\" or \"playstation\". #{helpText}"
        deferred.reject()
        return
      else if results[0]
        deferred.resolve({platform: '1', membershipId: results[0]})
      else if results[1]
        deferred.resolve({platform: '2', membershipId: results[1]})
      else
        robot.send {room: res.message.user.name, "unfurl_media": false}, "Could not find guardian with name: #{displayName} on either platform. #{helpText}"
        deferred.reject()
        return
      deferred.promise

# Gets general player information from a player's gamertag
getPlayerId = (res, membershipType, displayName, robot) ->
  deferred = new Deferred()
  endpoint = "SearchDestinyPlayer/#{membershipType}/#{displayName}"

  makeRequest res, endpoint, null, (err, response) ->
    playerId = null
    foundData = response[0]

    if foundData
      playerId = foundData.membershipId

    deferred.resolve(playerId)
  deferred.promise

# Gets characterId for last played character
getCharacterId = (bot, membershipType, playerId, robot) ->
  deferred = new Deferred()
  endpoint = "#{membershipType}/Account/#{playerId}"

  makeRequest bot, endpoint, null, (err, response) ->
    if !response
      robot.send {room: bot.message.user.name, "unfurl_media": false}, "Something went wrong, no characters found for this user. #{helpText}"
      deferred.reject()
      return

    data = response.data
    character = data.characters[0]

    characterId = character.characterBase.characterId
    deferred.resolve(characterId)

  deferred.promise

# Gets itemInstanceId from Inventory Summary based on bucket
getItemIdFromSummary = (bot, membershipType, playerId, characterId, bucket, robot) ->
  deferred = new Deferred()
  endpoint = "#{membershipType}/Account/#{playerId}/Character/#{characterId}/Inventory/Summary"

  makeRequest bot, endpoint, null, (err, response) ->
    data = response.data
    items = data.items

    matchesBucketHash = (object) ->
      "#{object.bucketHash}" is "#{bucket}"

    item = items.filter(matchesBucketHash)
    if item.length is 0
      robot.send {room: bot.message.user.name, "unfurl_media": false}, "Something went wrong, couldn't find the requested item for this character. #{helpText}"
      deferred.reject()
      return

    itemInstanceId = item[0].itemId
    deferred.resolve(itemInstanceId)

  deferred.promise

# returns item details
getItemDetails = (bot, membershipType, playerId, characterId, itemInstanceId) ->
  deferred = new Deferred()
  endpoint = "#{membershipType}/Account/#{playerId}/Character/#{characterId}/Inventory/#{itemInstanceId}"
  params = 'definitions=true'

  makeRequest bot, endpoint, params, (err, response) ->
    item = dataHelper.serializeFromApi(response)
    deferred.resolve(item)

  deferred.promise

getPublicWeeklyActivity = (bot, activityKey) ->

  deferred = new Deferred()
  endpoint = "Advisors/V2"
  makeRequest bot, endpoint, null, (err, response) ->

    activityDetails = dataHelper.serializeActvity(response, activityKey)
    if activityKey not in constants.FURTHER_DETAILS
      return deferred.resolve(activityDetails)

    parseActivityHash(bot, activityDetails.activityHash).then (details) ->
      combinedDetails = Object.assign {}, activityDetails, details
      deferred.resolve(combinedDetails)

  deferred.promise

parseActivityHash = (bot, activityHash) ->
  deferred = new Deferred()
  endpoint = "Manifest/Activity/#{activityHash}"

  makeRequest bot, endpoint, null, (err, response) ->

    if err
      return deferred.resolve(err)

    deferred.resolve(dataHelper.serializeActivityDetails(response))

  deferred.promise

# Sends GET request from an endpoint, needs a success callback
makeRequest = (bot, endpoint, params, callback) ->
  BUNGIE_API_KEY = process.env.BUNGIE_API_KEY
  baseUrl = 'https://www.bungie.net/Platform/Destiny/'
  trailing = '/'
  queryParams = if params then '?'+params else ''
  url = baseUrl+endpoint+trailing+queryParams

  console.log("making request: #{url}")

  bot.http(url)
    .header('X-API-Key', BUNGIE_API_KEY)
    .get() (err, response, body) ->
      if err
        console.log("error: #{err}")
        return callback(err)

      object = JSON.parse(body)
      callback(null, object.Response)
