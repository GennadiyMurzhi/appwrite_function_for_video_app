import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:dart_appwrite/dart_appwrite.dart';
import 'package:pocketbase/pocketbase.dart';

Future<void> start(final req, final res) async {
  final Client client = Client();
  final Account account = Account(client);
  final Storage storage = Storage(client);

  client
      .setEndpoint('http://192.168.1.154/v1')
      .setProject(req.env['APPWRITE_FUNCTION_PROJECT_ID'])
      .setKey(
          'df4da3b659dc9635ce7664a90adf72b4002ef42ef28e5d9d78e7d0628eaf003b82fba7c07ef1abb3694f7ebbde90ebca8f11ae7958efbfa7fd6c55a90e101eacf95eadcc06e77d131b2e610abf3adbfcbb2862e64ff6b9febbecdb1ec339eb3fd7978b765ac8069da4d3d53e604a74b6b274256895a7a252fe82d34bdb4dff62')
      .setSelfSigned();

  final pocketBaseClient = PocketBase('http://192.168.1.154:8090');

  final Map<String, dynamic> eventData =
      json.decode(req.env["APPWRITE_FUNCTION_EVENT_DATA"]);

  var eventRecordResult;
  var getVideoResult;
  var videoRecordResult;

  await pocketBaseClient.records.create('appwrite_events', body: {
    'event_name': _eventName(req.env["APPWRITE_FUNCTION_EVENT"]),
    'file_name': eventData['name'],
    'fileId_id': eventData['\$id'],
    'bucket_id': eventData['bucketId'],
  }).then(
    (value) {
      eventRecordResult = value;
    },
  ).catchError((err) {
    eventRecordResult = 'err: $err';
  });

  if (_eventName(req.env["APPWRITE_FUNCTION_EVENT_DATA"]) == 'create') {
    ///using getFileView because don't need another information
    final Uint8List video = await storage
        .getFileView(
      bucketId: eventData['bucketId'],
      fileId: eventData['\$id'],
    )
        .then((value) {
      getVideoResult = 'succescs';
      return value;
    }).catchError((err) {
      getVideoResult = 'err: $err';
    });

    await pocketBaseClient.records.create(
      'video',
      files: [
        http.MultipartFile.fromBytes(
          'video_file',
          video,
          filename: eventData['name'],
        ),
      ],
    ).then(
      (value) {
        videoRecordResult = value;
      },
    ).catchError((err) {
      videoRecordResult = 'err: $err';
    });
  }

  res.json({
    'eventRecordResult': eventRecordResult,
    'getVideoResult': getVideoResult,
    'videoRecordResult': videoRecordResult,
  });
}

///method for detect event name
String _eventName(String eventEnv) {
  if (eventEnv.contains('create')) {
    return 'create';
  }
  if (eventEnv.contains('delete')) {
    return 'delete';
  } else {
    return 'unexpected event $eventEnv';
  }
}
