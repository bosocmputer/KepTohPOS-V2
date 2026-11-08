/// Outside the browser there is no Web Crypto; offline PINs are web-only.
Future<String> hashPin(String pin, String salt) =>
    throw UnsupportedError('offline PIN check needs a browser');
