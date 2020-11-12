JSON = require "dkjson" -- load additional json routines

-- Probe function.
function probe()
  if vlc.access == "http" or vlc.access == "https" then
    peeklen = 9
    s = ""
    while string.len(s) < 9 do
      s = string.lower(string.gsub(vlc.peek(peeklen), "%s", ""))
      peeklen = peeklen+1
    end
    return s == "<!doctype"
  else
    return false
  end
end

-- Parse function.
function parse()
  local url = vlc.access.."://"..vlc.path -- get full url

  --checks if youtube-dl exists, else download the right file or update it

  local file = assert(io.popen('youtube-dl -j --flat-playlist '..url, 'r'))  --run youtube-dl in json mode
  local tracks = {}
  for output in file:lines() do
    if not output then
      return nil
    end

    local json = JSON.decode(output) -- decode the json-output from youtube-dl
    
    if not json then
      return nil
    end
    
    local outurl = json.url
    if not outurl then
      -- choose best
      outurl = json.formats[#json.formats].url
      -- prefer streaming formats
      for key, format in pairs(json.formats) do
        if format.manifest_url and format.vcodec and format.vcodec ~= "none" and format.acodec and format.acodec ~= "none" then
          outurl = format.manifest_url
        end
      end
      -- prefer audio and video
      for key, format in pairs(json.formats) do
        if format.vcodec and format.vcodec ~= "none" and format.acodec and format.acodec ~= "none" then
          outurl = format.url
        end
      end
    end
    
    if outurl then
      if (json._type == "url" or json._type == "url_transparent") and json.ie_key == "Youtube" then
        outurl = "https://www.youtube.com/watch?v="..outurl
      end

      local category = nil
      if json.categories then
        category = json.categories[1]
      end
      
      local year = nil
      if json.release_year then
        year = json.release_year
      elseif json.release_date then
        year = string.sub(json.release_date, 1, 4)
      elseif json.upload_date then
        year = string.sub(json.upload_date, 1, 4)
      end
      
      local thumbnail = nil
      if json.thumbnails then
        thumbnail = json.thumbnails[#json.thumbnails].url
      end
      
      jsoncopy = {}
      for k in pairs(json) do
        jsoncopy[k] = tostring(json[k])
      end
      
      json = jsoncopy

      item = {
        path         = outurl;
        name         = json.title;
        duration     = json.duration;
        
        -- for a list of these check vlc/modules/lua/libs/sd.c
        title        = json.track or json.title;
        artist       = json.artist or json.creator or json.uploader or json.playlist_uploader;
        genre        = json.genre or category;
        copyright    = json.license;
        album        = json.album or json.playlist_title or json.playlist;
        tracknum     = json.track_number or json.playlist_index;
        description  = json.description;
        rating       = json.average_rating;
        date         = year;
        --setting
        url          = json.webpage_url or url;
        --language
        --nowplaying
        --publisher
        --encodedby
        arturl       = json.thumbnail or thumbnail;
        trackid      = json.track_id or json.episode_id or json.id;
        tracktotal   = json.n_entries;
        --director
        season       = json.season or json.season_number or json.season_id;
        episode      = json.episode or json.episode_number;
        show_name    = json.series;
        --actors
        
        meta         = json;
      }
      table.insert(tracks, item)
    end
  end
  if file:close() then
    return tracks
  else
    return nil
  end
end

