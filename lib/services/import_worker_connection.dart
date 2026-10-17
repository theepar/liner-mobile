import 'dart:io';

abstract interface class WorkerConnection {
  Stream<String> get messages;

  Future<void> close();
}

typedef WorkerConnector = Future<WorkerConnection> Function(Uri uri);

Future<WorkerConnection> connectToImportWorker(Uri uri) async {
  // Closed through WorkerConnection.close.
  // ignore: close_sinks
  final socket = await WebSocket.connect(
    uri.toString(),
  ).timeout(const Duration(seconds: 10));
  return _SocketConnection(socket);
}

class _SocketConnection implements WorkerConnection {
  _SocketConnection(this._socket);

  final WebSocket _socket;

  @override
  Stream<String> get messages =>
      _socket.where((message) => message is String).cast<String>();

  @override
  Future<void> close() => _socket.close();
}
