# Description:
#   Gets Bus Schedule Information
#
# Configuration:
#   WPG_OPENDATA_KEY=WE07Dsr4wm7sJSQpyNR
#   WPG_OPENDATA_URL=http://api.winnipegtransit.com/v2/
#
# Commands:
#  hubot bus search <query> - Search for a stop number
#  hubot bus schedule - Display current bus schedule for the last bus stop that you viewed
#  hubot bus schedule <stop number> - Display current bus schedule for specified stop
#
# Notes:
#  Alternate OPENDATA api key: M1b8OF3ANVYQx_b_eNcr
#
# Author:
#   jneufeld <jordan.neufeld@nfl.com
#
moment = require('moment')
stopsJSON = require('../bus_stops.json')
api_url = process.env.WPG_OPENDATA_URL
api_key = process.env.WPG_OPENDATA_KEY
module.exports = (robot) ->
  getSchedule = (msg, cb) ->
    now = new moment()
    #Adjust from LA time to WPG time
    wpgTime = now.add('2','hours')
    #futureTime is how far in advance we want to display schedule for
    futureTime = wpgTime.add('1.25','hours').format('HH:mm')
    console.log("#{api_url}stops/#{msg}/schedule.json?end=#{futureTime}&usage=long&max-results-per-route=4&api-key=#{api_key}")
    httprequest = robot.http("#{api_url}stops/#{msg}/schedule.json?end=#{futureTime}&usage=long&max-results-per-route=4&api-key=#{api_key}")
    httprequest.get() (err, res, body) ->
      if err or res.statusCode != 200
        cb "An Error occurred: " + body
      else
        cb null, body
  #Retrieve schedule by stop number
  robot.respond /bus schedules? ?(\d{5}|)$/i, (msg) ->
    preferredStop = robot.brain.get("preferred_stop_#{msg.message.user.id}")
    #If user left the stop number field blank, perform some logic
    if !msg.match[1]
      #if we find a preferred route in hubot's brain
      if preferredStop
        msg.match[1] = preferredStop
      else
        #did not find a preferred route and we were not given a stop number
        msg.send "I couldn't find any bus stop history for you #{msg.message.user.name}, please provide a 5 digit stop number."
        return
    getSchedule msg.match[1], (err, body) ->
      if err
        msg.send err
      else
        #Got successful result; remember this preferred route in hubot's brain
        robot.brain.set "preferred_stop_#{msg.message.user.id}", msg.match[1]
        bodyJSON = JSON.parse(body)
        stopName = bodyJSON['stop-schedule']['stop']['name']
        stopNumber = bodyJSON['stop-schedule']['stop']['number']
        routeSchedulesArray = bodyJSON['stop-schedule']['route-schedules']
        sortedRoutesArray = []
        i = 0
        while i < routeSchedulesArray.length
          routeScheduleObj = routeSchedulesArray[i]
          scheduledStopsArray = routeScheduleObj['scheduled-stops']
          s = 0
          while s < scheduledStopsArray.length
            scheduledStop = scheduledStopsArray[s]
            estimatedArrival = new moment(scheduledStop.times.arrival.estimated)
            sortedRoutesArray.push({estimatedArrival: estimatedArrival, routeNumber: routeScheduleObj.route.number, routeName: scheduledStop.variant.name})
            s++
          i++
        #Sort the array by date
        sortedRoutesArray.sort (a, b) ->
          new Date(a.estimatedArrival) - (new Date(b.estimatedArrival))
        scheduleData = ""
        d = 0
        while d < sortedRoutesArray.length
          scheduleData += "#{sortedRoutesArray[d].estimatedArrival.format('hh:mm')} - [#{sortedRoutesArray[d].routeNumber}] #{sortedRoutesArray[d].routeName}\n"
          d++
        msg.send "```Stop Number #{stopNumber} | #{stopName}\n Time - Route\n#{scheduleData.substring(0,2000)}```"
  #Search for stop number
  robot.respond /bus search (.*)/i, (msg) ->
    searchTerm = msg.match[1].toLowerCase().replace(".","").replace("’","'")
    resultsData = ""
    resultsCount = 0
    searchLimit = 25
    s = 0
    while s < stopsJSON.length
      for key of stopsJSON[s]
        # `key = key`
        if stopsJSON[s][key].toLowerCase().replace(".","").indexOf(searchTerm) != -1 and resultsCount < searchLimit
          resultsData += "Stop Number #{key} | #{stopsJSON[s][key]}\n"
          resultsCount++
      s++
    msg.send "```Search Results (limited to 25):\n#{resultsData}```”