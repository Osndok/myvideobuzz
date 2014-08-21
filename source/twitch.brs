'******************************************************************************
' Twitch.brs
' Adds support for handling Twitch's json feed for livestreams
' Documentation on the API is here:
'             www.johannesbader.ch/2014/01/find-video-url-of-twitch-tv-live-streams-or-past-broadcasts/
'           and here:
'             https://github.com/justintv/twitch-api
'******************************************************************************
'Sub ViewTwitch(youtube as Object)
'    newTwitchVideo( "gassymexican" )
'End Sub

'******************************************************************************
' Main function to begin displaying Twitch content
' @param youtube the current youtube instance
' @param url an optional URL with the multireddit to query, or the full link to parse. This is used when hitting the 'More Results' or 'Back' buttons on the video list page.
'     multireddits look like this: videos+funny+humor for /r/videos, /r/funny, and /r/humor
'******************************************************************************
Sub ViewTwitch(youtube as Object, urlToQuery = "https://api.twitch.tv/kraken/games/top?hls=true&limit=50" as String )
    'https://api.twitch.tv/kraken/games/top?hls=true
    title = "Twitch Games"
    screen = uitkPreShowPosterMenu( "arced-portrait", title )
    screen.showMessage( "Loading Twitch games..." )
    rsp = QueryForJson( urlToQuery )
    
    if ( rsp.status = 200 ) then
        gameList = newTwitchGameList( rsp.json )

        ' Now add the 'More results' button
        if ( rsp.json._links <> invalid AND rsp.json._links.next <> invalid ) then
                gameList.Push({shortDescriptionLine1: "More Results", action: "next", pageURL: rsp.json._links.next, HDPosterUrl:"pkg:/images/icon_next_episode.jpg", SDPosterUrl:"pkg:/images/icon_next_episode.jpg"})
        end if
        ' gameList.Unshift({shortDescriptionLine1: "Back", action: "prev", HDPosterUrl:"pkg:/images/icon_prev_episode.jpg", SDPosterUrl:"pkg:/images/icon_prev_episode.jpg"})
        onselect = [1, gameList, youtube,
        function(menu, youtube, set_idx)
            if (menu[set_idx]["action"] <> invalid) then
                ViewTwitch(youtube, menu[set_idx]["pageURL"] )
            else
                ViewTwitchStreams( menu[set_idx]["TitleSeason"] )
            end if
            return set_idx
        end function]
        uitkDoPosterMenu(gameList, screen, onselect)
    else
        ShowErrorDialog( "Error querying Twitch (Code: " + tostr( rsp.status ) + ")", "Twitch Error" )
    end if
End Sub

'******************************************************************************
' Main function to begin displaying Twitch content
' @param youtube the current youtube instance
' @param url an optional URL with the multireddit to query, or the full link to parse. This is used when hitting the 'More Results' or 'Back' buttons on the video list page.
'     multireddits look like this: videos+funny+humor for /r/videos, /r/funny, and /r/humor
'******************************************************************************
Sub ViewTwitchStreams(gameName as String, urlToQuery = invalid as dynamic )
    'https://api.twitch.tv/kraken/games/top?hls=true
    title = gameName
    screen = uitkPreShowPosterMenu( "flat-episodic-16x9", title )
    screen.showMessage( "Loading Streams for " + gameName )
    if ( urlToQuery = invalid ) then
        urlToQuery = "https://api.twitch.tv/kraken/streams?limit=50&game=" + URLEncode(gameName)
    end if
    rsp = QueryForJson( urlToQuery )
    
    if ( rsp.status = 200 ) then
        streamList = NewTwitchStreamList( rsp.json )

        ' Now add the 'More results' button
        if ( rsp.json._links <> invalid AND rsp.json._links.next <> invalid ) then
                streamList.Push({shortDescriptionLine1: "More Results", action: "next", pageURL: rsp.json._links.next, HDPosterUrl:"pkg:/images/icon_next_episode.jpg", SDPosterUrl:"pkg:/images/icon_next_episode.jpg"})
        end if
        ' gameList.Unshift({shortDescriptionLine1: "Back", action: "prev", HDPosterUrl:"pkg:/images/icon_prev_episode.jpg", SDPosterUrl:"pkg:/images/icon_prev_episode.jpg"})
        onselect = [1, streamList, gameName,
        function(menu, gameName, set_idx)
            if (menu[set_idx]["action"] <> invalid) then
                ViewTwitchStreams( menu[set_idx]["pageURL"] )
            else
                newTwitchVideo( menu[set_idx]["ID"] )
            end if
            return set_idx
        end function]
        uitkDoPosterMenu(streamList, screen, onselect)
    else
        ShowErrorDialog( "Error querying Twitch (Code: " + tostr( rsp.status ) + ")", "Twitch Error" )
    end if
End Sub

Function NewTwitchGameList(jsonObject As Object) As Object
    gameList = []
    for each record in jsonObject.top
        gameList.Push( NewTwitchGameLink( record ) )
    next
    return gameList
End Function

Function NewTwitchStreamList(jsonObject As Object) As Object
    streamList = []
    for each record in jsonObject.streams
        streamList.Push( NewTwitchStreamLink( record ) )
    next
    return streamList
End Function

Function newTwitchVideo( channel as String ) As Object
    result = QueryForJson( "http://api.twitch.tv/api/channels/" + channel + "/access_token?as3=t&allow_source=true" )
    print "Sig: " ; result.json.sig
    print "Token: " ; result.json.token
    'QueryForJson( "http://usher.twitch.tv/select/" + channel + ".json?nauthsig=" + result.json.sig +"&nauth=" + result.json.token )'+ "&allow_source=true" )
    meta                   = {}
    meta["Author"]                 = channel
    meta["TitleSeason"]            = channel + " Live"
    meta["Title"]                  = meta["Author"]
    meta["Actors"]                 = meta["Author"]
    meta["FullDescription"]        = "Live Stream"
    meta["Description"]            = "Lame"
    meta["Categories"]             = "Live Stream"
    meta["ShortDescriptionLine1"]  = meta["TitleSeason"]
    meta["ShortDescriptionLine2"]  = meta["Title"]
    meta["SDPosterUrl"]            = getDefaultThumb( invalid, "" )
    meta["HDPosterUrl"]            = getDefaultThumb( invalid, "" )
    meta["Length"]                 = 0
    meta["UserID"]                 = channel
    meta["StreamFormat"]           = "hls"
    meta["Live"]                   = true
    meta["Streams"]                = []
    meta["Source"]                 = "twitch"
    ' Set the PlayStart sufficiently large so it starts at 'Live' position
    meta["PlayStart"]              = 500000
    meta["SwitchingStrategy"]      = "no-adaptation"
    meta["Streams"].Push({url: "http://usher.twitch.tv/select/" + channel + ".json?nauthsig=" + result.json.sig +"&nauth=" + result.json.token + "&allow_source=true", bitrate: 0, quality: false, contentid: -1})
    DisplayVideo(meta)
    return meta
End Function

'******************************************************************************
' Creates a video roAssociativeArray, with the appropriate members needed to set Content Metadata and play a video with
' This function handles sites that require parsing a response for an MP4 URL (LiveLeak, Vine)
' @param jsonObject the JSON "data" object that was received in QueryForJson, this is one result of many
' @return an roAssociativeArray of metadata for the current result
'******************************************************************************
Function NewTwitchGameLink(jsonObject As Object) As Object
    game                   = {}

    game["ID"]                      = tostr( jsonObject.game._id )
    game["TitleSeason"]             = jsonObject.game.name
    game["Categories"]              = "Vidya Game"
    game["Source"]                  = "Twitch"
    game["Thumb"]                   = jsonObject.game.box.large
    game["ContentType"]             = "game"
    game["Title"]                   = "Viewers: " + tostr( jsonObject.viewers )
    game["FullDescription"]         = ""
    game["Description"]             = tostr( jsonObject.channels ) + " Channels"
    game["ShortDescriptionLine1"]   = game["TitleSeason"]
    game["ShortDescriptionLine2"]   = game["Title"]
    game["SDPosterUrl"]             = jsonObject.game.box.medium
    game["HDPosterUrl"]             = jsonObject.game.box.large
    return game
End Function

'******************************************************************************
' Creates a video roAssociativeArray, with the appropriate members needed to set Content Metadata and play a video with
' This function handles sites that require parsing a response for an MP4 URL (LiveLeak, Vine)
' @param jsonObject the JSON "data" object that was received in QueryForJson, this is one result of many
' @return an roAssociativeArray of metadata for the current result
'******************************************************************************
Function NewTwitchStreamLink(jsonObject As Object) As Object
    game                   = {}

    game["ID"]                      = jsonObject.channel.name
    game["TitleSeason"]             = jsonObject.channel.display_name + " [Viewers: " + tostr( jsonObject.viewers ) + "]"
    game["Categories"]              = jsonObject.game
    game["Source"]                  = "Twitch"
    game["Thumb"]                   = jsonObject.preview.large
    game["ContentType"]             = "game"
    game["Title"]                   = jsonObject.channel.display_name
    game["FullDescription"]         = ""
    game["Description"]             = jsonObject.channel.status
    game["ShortDescriptionLine1"]   = game["TitleSeason"]
    game["ShortDescriptionLine2"]   = game["Title"]
    game["SDPosterUrl"]             = jsonObject.preview.medium
    game["HDPosterUrl"]             = jsonObject.preview.large
    return game
End Function