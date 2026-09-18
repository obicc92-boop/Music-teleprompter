import 'dart:async';
import 'dart:convert';
import 'dart:io';

enum RemoteAction {
  playPause,
  speedUp,
  speedDown,
  nextSection,
  prevSection,
  nextSong,
  prevSong,
  cueAdvance,
  resetToStart,
}

class RemoteControlServer {
  static const int _port = 8765;

  HttpServer? _server;
  String? _localIp;

  final void Function(RemoteAction) onCommand;

  RemoteControlServer({required this.onCommand});

  int get port => _server?.port ?? _port;
  String? get localIp => _localIp;
  String? get url => _localIp != null ? 'http://$_localIp:$_port' : null;
  bool get isRunning => _server != null;

  /// Built with `--dart-define=MT_NO_REMOTE=true`, the server never starts:
  /// automated test runs would otherwise trip the firewall prompt on Windows.
  static const _disabled = bool.fromEnvironment('MT_NO_REMOTE');

  Future<String?> start() async {
    if (_disabled) return null;
    if (_server != null) return url;
    try {
      _localIp = await _getLocalIp();
      _server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        _port,
        shared: true,
      );
      _serve();
      return url;
    } catch (_) {
      _server = null;
      return null;
    }
  }

  void stop() {
    _server?.close(force: true);
    _server = null;
  }

  void _serve() async {
    final server = _server;
    if (server == null) return;
    await for (final req in server) {
      _handle(req);
    }
  }

  Future<void> _handle(HttpRequest req) async {
    req.response.headers.set('Access-Control-Allow-Origin', '*');
    req.response.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');

    if (req.method == 'OPTIONS') {
      req.response.statusCode = 200;
      await req.response.close();
      return;
    }

    final path = req.uri.path;

    if ((path == '/' || path == '/index.html') && req.method == 'GET') {
      req.response.headers.contentType = ContentType.html;
      req.response.write(_remoteHtml());
      await req.response.close();
      return;
    }

    if (path == '/cmd' && req.method == 'POST') {
      try {
        final body = await utf8.decodeStream(req);
        final data = jsonDecode(body) as Map<String, dynamic>;
        final action = _parseAction(data['action'] as String?);
        if (action != null) onCommand(action);
        req.response.statusCode = 200;
        req.response.headers.contentType = ContentType.json;
        req.response.write('{"ok":true}');
      } catch (_) {
        req.response.statusCode = 400;
        req.response.write('{"ok":false}');
      }
      await req.response.close();
      return;
    }

    req.response.statusCode = 404;
    await req.response.close();
  }

  static RemoteAction? _parseAction(String? s) => switch (s) {
        'playPause'    => RemoteAction.playPause,
        'speedUp'      => RemoteAction.speedUp,
        'speedDown'    => RemoteAction.speedDown,
        'nextSection'  => RemoteAction.nextSection,
        'prevSection'  => RemoteAction.prevSection,
        'nextSong'     => RemoteAction.nextSong,
        'prevSong'     => RemoteAction.prevSong,
        'cueAdvance'   => RemoteAction.cueAdvance,
        'resetToStart' => RemoteAction.resetToStart,
        _              => null,
      };

  static Future<String> _getLocalIp() async {
    try {
      final ifaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in ifaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  // ── Embedded remote-control web page ────────────────────────────────────────

  static String _remoteHtml() => '''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<title>Teleprompter Remote</title>
<style>
*{box-sizing:border-box;margin:0;padding:0;-webkit-tap-highlight-color:transparent}
html,body{height:100%;background:#090909;color:#fff;font-family:-apple-system,system-ui,monospace;overscroll-behavior:none}
body{display:flex;flex-direction:column;padding:14px 12px;gap:10px;max-width:420px;margin:0 auto}
header{text-align:center;padding:6px 0 2px}
header h1{font-size:12px;letter-spacing:3px;color:#444;text-transform:uppercase;font-weight:600}
header p{font-size:11px;color:#333;letter-spacing:1px;margin-top:2px}
.btn{border:none;border-radius:14px;cursor:pointer;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:5px;transition:transform .08s,filter .08s;-webkit-user-select:none;user-select:none;touch-action:manipulation}
.btn:active{transform:scale(.93);filter:brightness(1.2)}
.btn .icon{font-size:26px;line-height:1}
.btn .lbl{font-size:9px;letter-spacing:1.5px;text-transform:uppercase;font-weight:700;opacity:.7}
.play{background:#c8ff00;color:#000;width:100%;padding:26px 16px;font-size:28px;font-weight:900;letter-spacing:2px}
.play.paused{background:#111;color:#c8ff00;border:2px solid #c8ff00}
.row{display:flex;gap:10px}
.half{flex:1;background:#151515;color:#bbb;padding:20px 10px}
.third{flex:1;background:#111;color:#888;padding:14px 6px}
.wide{width:100%;background:#151515;color:#bbb;padding:18px 16px}
.danger{background:#111;color:#555;border:1px solid #222;padding:12px 10px;width:100%}
#status{text-align:center;font-size:10px;color:#333;letter-spacing:1px;padding:4px 0;min-height:18px}
</style>
</head>
<body>
<header>
  <h1>&#127925; Teleprompter Remote</h1>
  <p id="songname">—</p>
</header>

<button class="btn play" id="playbtn" onclick="send('playPause')">
  <span id="playicon">&#9654;</span>
  <span id="playlbl" class="lbl">Play</span>
</button>

<div class="row">
  <button class="btn half" onclick="send('prevSection')">
    <span class="icon">&#9664;&#9664;</span>
    <span class="lbl">Prev Section</span>
  </button>
  <button class="btn half" onclick="send('nextSection')">
    <span class="icon">&#9654;&#9654;</span>
    <span class="lbl">Next Section</span>
  </button>
</div>

<div class="row">
  <button class="btn half" onclick="send('speedDown')">
    <span class="icon">&#9660;</span>
    <span class="lbl">Slower</span>
  </button>
  <button class="btn half" onclick="send('speedUp')">
    <span class="icon">&#9650;</span>
    <span class="lbl">Faster</span>
  </button>
</div>

<button class="btn wide" onclick="send('cueAdvance')">
  <span class="icon">&#11015;</span>
  <span class="lbl">Cue Advance  (line by line)</span>
</button>

<div class="row">
  <button class="btn third" onclick="send('prevSong')">
    <span class="icon">&#9198;</span>
    <span class="lbl">Prev Song</span>
  </button>
  <button class="btn third" onclick="send('nextSong')">
    <span class="icon">&#9197;</span>
    <span class="lbl">Next Song</span>
  </button>
  <button class="btn third danger" onclick="send('resetToStart')">
    <span class="icon">&#8635;</span>
    <span class="lbl">Reset</span>
  </button>
</div>

<div id="status">Ready</div>

<script>
async function send(action){
  const s=document.getElementById('status');
  try{
    const r=await fetch('/cmd',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({action})});
    s.textContent=r.ok?action+' ✓':'Error '+r.status;
  }catch(e){s.textContent='Connection lost';}
}
</script>
</body>
</html>
''';
}
