import 'package:queue_quandry/credentials.dart';
import 'package:queue_quandry/pages/lobby.dart';
import 'package:queue_quandry/pages/login.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'multiplayer.dart';

class Track {
  final String track_id;
  late String track_uri;
  late String imageUrl = "";
  late String name = "";
  late String artist = "";
  late int duration_ms = 0;
  bool _isInitialized = false;

  Track(this.track_id) {
    _fetchData();
  }

  bool isInitialized() {
    return _isInitialized;
  }

  Future<void> _fetchData() async {
    final String url = 'https://api.spotify.com/v1/tracks/$track_id';

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $myToken',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      name = data['name'];
      artist = data['artists'][0]['name'];
      imageUrl = data['album']['images'][0]['url'];
      track_uri = data['uri'];
      duration_ms = data['duration_ms'];

      _isInitialized = true;
    } else {
      throw Exception('Failed to load track');
    }
  }
}

class Player {
  final String _user_id;
  late String _display_name;
  late String _image;
  bool _isInitialized = false;
  int _score = 0;

  Player(this._user_id) {
    // on creation, grab the data from Spotify
    _fetchData();
  }

  int getScore() {
    return _score;
  }

  void setScore(int value) {
    _score = value;
  }

  bool isInitialized() {
    return _isInitialized;
  }

  String getDisplayName() {
    return _display_name;
  }

  String getUserID() {
    return _user_id;
  }

  String getImageURL() {
    return _image;
  }

  Future<void> _fetchData() async {
    await ensureTokenIsValid();

    _display_name = await _getDisplayName();
    _image = await _getUserPicture();

    // once these fields are populated we can say this is initialized
    _isInitialized = true;
  }

  @override
  String toString() {
    if (_isInitialized) return "Name: $_display_name, Score: $_score";

    return "<unknown-player>";
  }

  Future<String> _getUserPicture() async {
    await ensureTokenIsValid();

    final response = await http.get(
      Uri.parse('https://api.spotify.com/v1/users/$_user_id'),
      headers: {
        'Authorization': 'Bearer $myToken',
      },
    );

    var responseData = json.decode(response.body);
    return responseData['images'][0]['url'];
  }

  Future<String> _getDisplayName() async {
    await ensureTokenIsValid();

    final response = await http.get(
      Uri.parse('https://api.spotify.com/v1/users/$_user_id'),
      headers: {
        'Authorization': 'Bearer $myToken',
      },
    );

    return json.decode(response.body)['display_name'];
  }
}

Future<void> pausePlayback() async {
  await ensureTokenIsValid();

  bool bIsPlaying = true;

  while (bIsPlaying == true) {
    final response = await http.get(
      Uri.parse('https://api.spotify.com/v1/me/player'),
      headers: {
        'Authorization': 'Bearer $myToken',
      },
    );

    bIsPlaying = json.decode(response.body)['is_playing'];

    await http.put(
      Uri.parse('https://api.spotify.com/v1/me/player/pause'),
      headers: {
        'Authorization': 'Bearer $myToken',
      },
    );
  }
}

Future<void> resumePlayback() async {
  await ensureTokenIsValid();

  await http.put(
    Uri.parse('https://api.spotify.com/v1/me/player/play'),
    headers: {
      'Authorization': 'Bearer $myToken',
    },
  );
}

Future<void> addToQueue(String? trackUri, String? accessToken) async {
  await ensureTokenIsValid();

  final url =
      Uri.parse('https://api.spotify.com/v1/me/player/queue?uri=$trackUri');

  final response = await http.post(
    url,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    },
  );

  if (response.statusCode == 204) {
    // print('Track added to queue successfully');
  } else {
    print(
        'Failed to add track to queue: ${response.statusCode}, ${response.body}');
  }
}

Future<String> getLocalUserID() async {
  final response = await http.get(
    Uri.parse('https://api.spotify.com/v1/me'),
    headers: {
      'Authorization': 'Bearer $myToken',
    },
  );

  return json.decode(response.body)['id'];
}

Future<void> skipTrack() async {
  await ensureTokenIsValid();

  final url = Uri.parse('https://api.spotify.com/v1/me/player/next');

  final response = await http.post(
    url,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $myToken',
    },
  );

  if (response.statusCode == 204) {
    print(response.body);
  } else {
    print("failed to skip track");
  }
}

Future<List<String>> getTopTracks(String? accessToken) async {
  await ensureTokenIsValid();

  final response = await http.get(
    Uri.parse('https://api.spotify.com/v1/me/top/tracks'),
    headers: {
      'Authorization': 'Bearer $myToken',
    },
  );

  if (response.statusCode == 200) {
    var temp = json.decode(response.body);

    List<String> topSongs = [];

    for (int i = 0; i < 5; i++) {
      topSongs.add(temp['items'][i]['id']);
    }

    // print(topSongs);
    return topSongs;
  } else {
    print('Failed to fetch top tracks.');
    return [];
  }
}

Future<Map<String, dynamic>> getCurrentTrack() async {
  await ensureTokenIsValid();

  final response = await http.get(
    Uri.parse('https://api.spotify.com/v1/me/player/currently-playing'),
    headers: {
      'Authorization': 'Bearer $myToken',
    },
  );

  var body = json.decode(response.body);
  print(body['item']['uri']);
  return body['item']['uri'];
}

Future<bool> isPlaying() async {
  await ensureTokenIsValid();

  final response = await http.get(
    Uri.parse('https://api.spotify.com/v1/me/player'),
    headers: {
      'Authorization': 'Bearer $myToken',
    },
  );

  var body = json.decode(response.body);
  return body['is_playing'];
}

Future<bool> isSongDonePlaying() async {
  final url =
      Uri.parse('https://api.spotify.com/v1/me/player/currently-playing');
  final response = await http.get(
    url,
    headers: {
      'Authorization': 'Bearer $myToken',
    },
  );

  if (response.statusCode == 200) {
    final jsonResponse = json.decode(response.body);

    // Get the progress and duration of the currently playing track
    final int progressMs = jsonResponse['progress_ms'];
    final int durationMs = jsonResponse['item']['duration_ms'];

    // Return true if the song is done playing
    return progressMs >= durationMs;
  } else if (response.statusCode == 204) {
    // No content (no track currently playing)
    return false;
  } else {
    throw Exception('Failed to get current track: ${response.statusCode}');
  }
}

Future<List<String>> searchQuery(String query) async {
  await ensureTokenIsValid();

  final String url = 'https://api.spotify.com/v1/search';

  try {
    final response = await http.get(
      Uri.parse(
          '$url?q=${Uri.encodeComponent(query)}&type=track&market=US&limit=5'),
      headers: {
        'Authorization': 'Bearer $myToken',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> tracks = data['tracks']['items'];
      List<String> trackIds =
          tracks.map<String>((track) => track['id'] as String).toList();
      return trackIds;
    } else {
      return [];
    }
  } catch (e) {
    return [];
  }
}

Future<bool> getPlaybackState() async {
  await ensureTokenIsValid();

  final response = await http.get(
    Uri.parse('https://api.spotify.com/v1/me/player'),
    headers: {
      'Authorization': 'Bearer $myToken',
    },
  );

  try {
    return json.decode(response.body)['is_playing'];
  } catch (e) {
    return false;
  }
}

Future<String?> getActiveDevice() async {
  final response = await http.get(
    Uri.parse('https://api.spotify.com/v1/me/player/devices'),
    headers: {
      'Authorization': 'Bearer $myToken',
    },
  );

  if (response.statusCode == 200) {
    final devices = json.decode(response.body)['devices'];
    for (var device in devices) {
      if (device['is_active'] == true) {
        return device['id'];
      }
    }
    return null;
  } else {
    throw Exception('Failed to get devices: ${response.reasonPhrase}');
  }
}

Future<int> playTrack(String track_id) async {
  await ensureTokenIsValid();

  String? deviceId = await getActiveDevice();
  String track_uri = "spotify:track:" + track_id;

  final response = await http.put(
    Uri.parse('https://api.spotify.com/v1/me/player/play'),
    headers: {
      'Authorization': 'Bearer $myToken',
      'Content-Type': 'application/json',
    },
    body: json.encode({
      'device_id': deviceId,
      'uris': [track_uri],
    }),
  );

  if (response.statusCode == 204) {
    return 0;
  } else {
    return -1;
  }
}

Future<dynamic> getTrackInfo(String track_id) async {
  await ensureTokenIsValid();

  final String url = 'https://api.spotify.com/v1/tracks/$track_id';
  final response = await http.get(
    Uri.parse(url),
    headers: {
      'Authorization': 'Bearer $myToken',
    },
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception('Failed to load track');
  }
}

Future<void> cleanSpotifyQueue() async {
  bool queueNotEmpty = true;

  while (queueNotEmpty) {
    try {
      await skipTrack();
    } catch (e) {
      queueNotEmpty = false;
      print('Queue is now empty or there was an error: $e');
    }
  }
}

Future<void> createPlaylist(String playlistName) async {
  final response = await http.post(
    Uri.parse('https://api.spotify.com/v1/users/$local_client_id/playlists'),
    headers: {
      'Authorization': 'Bearer $myToken',
      'Content-Type': 'application/json',
    },
    body: json.encode({
      'name': playlistName,
      'public': false, // Change to true if you want the playlist to be public
    }),
  );

  if (response.statusCode == 201) {
    final playlistData = json.decode(response.body);
    final playlistId = playlistData['id'];

    // Add tracks to the newly created playlist
    await addTracksToPlaylist(playlistId);
  } else {
    throw Exception('Failed to create playlist: ${response.reasonPhrase}');
  }
}

Future<void> addTracksToPlaylist(String playlistId) async {
  List<String> song_uris = [];

  for (int i = 0; i < playlist.value.length; i++) {
    song_uris.add('spotify:track:${playlist.value[i].keys.first}');
  }

  final response = await http.post(
    Uri.parse('https://api.spotify.com/v1/playlists/$playlistId/tracks'),
    headers: {
      'Authorization': 'Bearer $myToken',
      'Content-Type': 'application/json',
    },
    body: json.encode({
      'uris': song_uris,
    }),
  );
}

Future<void> setVolumeLevel(int percent) async {
  final url = Uri.parse('https://api.spotify.com/v1/me/player/volume');
  final response = await http.put(
    url,
    headers: {
      'Authorization': 'Bearer $myToken',
      'Content-Type': 'application/json',
    },
    body: json.encode({
      'volume_percent': percent,
    }),
  );

  if (response.statusCode == 204) {
    print('Volume set to zero successfully.');
  } else {
    print(
        'Failed to set volume: ${response.statusCode} - ${response.reasonPhrase}');
  }
}

Future<int> locatePlayer() async {
  final url = Uri.parse('https://api.spotify.com/v1/me/player/devices');

  final response = await http.get(
    url,
    headers: {
      'Authorization': 'Bearer $myToken',
      'Content-Type': 'application/json',
    },
  );

  if (response.statusCode == 200) {
    final devices = json.decode(response.body)['devices'];

    for (var device in devices) {
      if (device['name'] == "Playlist Pursuit") {
        print("found da player");

        return 0;
      }
    }
  } else {
    print('Error: ${response.reasonPhrase}');
  }

  return -1;
}
