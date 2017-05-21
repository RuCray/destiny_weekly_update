require('dotenv').load()
Deferred = require('promise.coffee').Deferred
Q = require('q')
DataHelper = require './bungie-data-helper.coffee'
Constants = require './constants.coffee'

dataHelper = new DataHelper
helpText = "Check out the full README here: https://github.com/RuCray/destiny_weekly_update"

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

    emitPayload = (payload) ->
      console.log 'Emitting payload:'
      console.log payload
      robot.emit('slack-attachment', payload)

    # activity should always be last input
    inputFirst = input[0].toLowerCase()
    activityKey = Constants.ACTIVITY_KEYS[inputFirst]
    if activityKey
      getPublicWeeklyActivity(res, activityKey).then (activityDetails) ->
        sendMessage(robot, res, [dataHelper.parseActivityDetails(activityDetails)])
      , (err) ->
        sendError(robot, res, err)

    else if inputFirst is 'vendor'
      for vendorHash in Constants.VENDORS
        getVendorDetails(res, vendorHash).then (saleItemCategories) ->
          return
        , (err) ->
          sendError(robot, res, err)

    else if inputFirst is 'bounties'
      if input.length < 2
        return sendError(robot, res, 'Please specify which vendor you\'re looking up bounties for.')

      vendors = Constants.BOUNTY_VENDORS[input[1]]
      if !vendors
        return sendError(robot, res, "Unable to locate vendor: #{input[1]}")

      bountyItems = []
      remainingIteration = vendors.length
      for vendorHash in vendors
        getVendorDetails(res, vendorHash).then (vendorDetails) ->
          for category in vendorDetails.saleItemCategories
            if category.categoryIndex in Constants.BOUNTIES_CATEGORY_INDICES
              bountyItems.push category.saleItems...
              --remainingIteration

              if remainingIteration is 0
                bountyItemsDetail = []
                remainingIteration = bountyItems.length
                for item in bountyItems
                  getItem(res, item.item.itemHash).then (itemDetails) ->
                    bountyItemsDetail.push {
                      itemName: itemDetails.itemName,
                      itemDescription: itemDetails.itemDescription,
                    }
                    --remainingIteration

                    if remainingIteration is 0
                      vendorBountiesDetail = {
                        vendorName: vendorDetails.vendorName,
                        bountyItemsDetail: bountyItemsDetail
                      }
                      attachment = dataHelper.parseVendorBountyDetails(vendorBountiesDetail)
                      sendMessage(robot, res, attachment)

                  , (err) ->
                    --remainingIteration
        , (err) ->
          -- remainingIteration

    else
      # command not recognized. Lists all available commands
      message = "Available commands are:\n"
      for command in Constants.COMMANDS
        message += "`#{command}`\n"
      message += "\n#{helpText}"
      return sendError(robot, res, message)

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
  message = "Available commands are:\n"
  for command in Constants.COMMANDS
    message += "`#{command}`\n"
  message += "\n#{helpText}"

  attachment =
    title: "Using the Weekly Bot"
    title_link: "https://github.com/RuCray/destiny_weekly_update"
    text: message
    fallback: message
    mrkdwn_in: ["text"]

  sendMessage(robot, res, attachment)

sendMessage = (robot, res, attachment) ->
  payload =
    message: res.message
    attachments: attachment
  console.log 'Emitting payload:'
  console.log payload
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
  console.log 'Sending error message:'
  console.log message
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

    if err
      console.log "Error fetching #{activityKey}: #{err}"
      return deferred.reject(err)

    activityDetails = dataHelper.serializeActvity(response, activityKey)

    if !activityDetails
      console.log 'No activity details found'
      return deferred.reject('No activity details found')

    if activityKey not in Constants.FURTHER_DETAILS
      console.log "Resolving activity details for #{activityKey}:"
      console.log activityDetails
      return deferred.resolve(activityDetails)

    parseActivityHash(bot, activityDetails.activityHash).then (details) ->

      console.log 'parseActivityHash success:'
      console.log details

      combinedDetails = dataHelper.merge activityDetails, details
      console.log "Resolving combined activity details for #{activityKey}:"
      console.log combinedDetails
      deferred.resolve(combinedDetails)

    , (err) ->

      console.log 'parseActivityHash failed:'
      console.log err

      deferred.reject(err)

  deferred.promise

parseActivityHash = (bot, activityHash) ->
  deferred = new Deferred()
  endpoint = "Manifest/Activity/#{activityHash}"

  makeRequest bot, endpoint, null, (err, response) ->

    if err
      return deferred.reject(err)

    deferred.resolve(dataHelper.serializeActivityDetails(response))

  deferred.promise

getVendorDetails = (bot, vendorHash) ->
  deferred = new Deferred()
  endpoint = "Vendors/#{vendorHash}"
  query = 'definitions=true'

  makeRequest bot, endpoint, query, (err, response) ->
    if err
      console.log 'Error getting vendor: ' + vendorHash
      console.log err
      return deferred.reject(err)

    if !response || !response.data || !response.data.saleItemCategories
      console.log 'Error getting vendor: ' + vendorHash
      return deferred.reject()

    if !response.definitions
    or !response.definitions.vendorDetails
    or !response.definitions.vendorDetails[vendorHash]
    or !response.definitions.vendorDetails[vendorHash].vendorName
        console.log 'Error getting vendor details: ' + vendorHash
        return deferred.reject()

    vendorDetails = {
      vendorName: response.definitions.vendorDetails[vendorHash].vendorName,
      salesItemCategories: response.data.saleItemCategories
    }
    deferred.resolve(vendorDetails)

  deferred.promise

getItem = (bot, itemHash) ->
  deferred = new Deferred()
  endpoint = "Manifest/InventoryItem/#{itemHash}"

  makeRequest bot, endpoint, null, (err, response) ->
    if err
      console.log 'Error getting item: ' + itemHash
      console.log err
      return deferred.reject(err)

    if !response || !response.data || !response.data.inventoryItem
      console.log 'Error getting item: ' + itemHash
      console.log response.data.inventoryItem
      return deferred.reject()

    item = response.data.inventoryItem
    console.log "#{itemHash} = #{item.itemName} - #{item.itemDescription}"
    deferred.resolve(item)

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

      console.log "response.statusCode: #{response.statusCode}"
      if err
        console.log("error: #{err}")
        return callback(err)

      json = JSON.parse(body)
      callback(null, json.Response)
