module Agents
  class InstagramLikes < Agent

    cannot_receive_events!

    description <<-MD
      The Instagram Likes Agent follows the likes list of the authenticated user.

      To be able to use this Agent you need to [authenticate with Instagram](https://www.instagram.com/developer/authentication/) and get the access_token.

      You must also provide the `number` of latest posts to monitor and `history` as number of posts that will be held in memory.

      Set `expected_update_period_in_days` to the maximum amount of time that you'd expect to pass between Events being created by this Agent.
    MD

    event_description <<-MD
      Events are the raw JSON provided by the [Instagram API](https://www.instagram.com/developer/endpoints/users/#get_users_feed_liked). Should look something like:
      {
        "attribution": null,
        "tags": [
          "thatsmytag"
        ],
        "type": "image",
        "location": null,
        "comments": {
          "count": 1
        },
        "filter": "Normal",
        "created_time": "1442432620",
        "link": "https://www.instagram.com/p/-9M9Hasdasd13fmHhGAaleQFgiZJQylJQQ0/",
        "likes": {
          "count": 6
        },
        "images": {
          "low_resolution": {
            "url": "https://scontent.cdninstagram.com/t51.2885-15/s320x320/e35/10584173_10325321156804467_1344335582_n.jpg?ig_cache_key=MTEzNDExOTY1NzI3NDU4ODAzOA%3D%3D.2",
            "width": 320,
            "height": 320
          },
          "thumbnail": {
            "url": "https://scontent.cdninstagram.com/t51.2885-15/s150x150/e35/10581173_13212532156804467_1341239182_n.jpg?ig_cache_key=MTEzNDExOTY1NzI3NDU4ODAzOA%3D%3D.2",
            "width": 150,
            "height": 150
          },
          "standard_resolution": {
            "url": "https://scontent.cdninstagram.com/t51.2885-15/s640x640/sh0.08/e35/10543273_10312321321804467_1323439182_n.jpg?ig_cache_key=MTEzNDExOTY1NzI3NDU4ODAzOA%3D%3D.2",
            "width": 640,
            "height": 640
          }
        },
        "users_in_photo": [

        ],
        "caption": {
          "created_time": "1449417620",
          "text": "Me explicando o que é Vlog Shopping, escutando Ariana Grande,  pedindo pau de selfie... Ê tempo que voa! #thatsmytag",
          "from": {
            "username": "brunomvsouza",
            "profile_picture": "https://scontent.cdninstagram.com/t51.2885-19/s150x150/12532113_9129999332181722_216724313_a.jpg",
            "id": "1097285",
            "full_name": "Bruno Souza"
          },
          "id": "17843412396812353"
        },
        "user_has_liked": false,
        "id": "1134119938593788038_1097285",
        "user": {
          "username": "brunomvsouza",
          "profile_picture": "https://scontent.cdninstagram.com/t51.2885-19/s150x150/12321379123_2369323281722_2571221233_a.jpg",
          "id": "10932115",
          "full_name": "Bruno Souza"
        }
      }
    MD

    default_schedule 'every_30m'

    API_BASE = 'https://api.instagram.com/v1'

    def default_options
      {
          number: '20',
          history: '100',
          access_token: '{% credential instagram_access_token %}',
          expected_update_period_in_days: '2'
      }
    end

    def validate_options
      errors.add(:base, 'access_token is required') unless options[:access_token].present?
      errors.add(:base, 'number is required') unless options[:number].present?
      errors.add(:base, 'history is required') unless options[:history].present?
      errors.add(:base, 'expected_update_period_in_days is required') unless options['expected_update_period_in_days'].present?
    end

    def working?
      event_created_within?(interpolated[:expected_update_period_in_days]) && !recent_error_logs?
    end

    def fetch_liked_stuff(payload)
      response = HTTParty.get("#{API_BASE}/users/self/media/liked", query: payload)
      json_body = JSON.parse(response.body)
      if !json_body || json_body['meta']['code'].to_i != 200
        log response.body
        []
      else
        json_body['data']
      end
    end

    def check
      memory[:last_seen] ||= []

      liked_stuff = fetch_liked_stuff(access_token: interpolated[:access_token], count: interpolated[:number])
      return unless liked_stuff.length > 0

      i = 0
      for ignored in liked_stuff
        stuff = liked_stuff[i]
        unless memory[:last_seen].include?(stuff['id'])
          memory[:last_seen].push(stuff['id'])
          memory[:last_seen].shift if memory[:last_seen].length > interpolated['history'].to_i
          create_event payload: stuff
        end
        i += 1
      end
    end
  end
end
