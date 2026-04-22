namespace Raphael {
    string uri_hostname (string uri) {
        try {
            var parsed = Uri.parse (uri, UriFlags.PARSE_RELAXED);
            return parsed.get_host () ?? uri;
        } catch (Error error) {
            return uri;
        }
    }
}
