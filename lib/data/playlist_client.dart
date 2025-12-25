import 'package:http/http.dart' as http;

abstract class PlaylistClient {
  Future<String> fetchPlaylist(String url);
}

class HttpPlaylistClient implements PlaylistClient {
  HttpPlaylistClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<String> fetchPlaylist(String url) async {
    final response = await _client.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to load M3U file');
    }
    return response.body;
  }
}
