import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/core/update/update_models.dart';
import 'package:sakuramusic/core/update/update_service.dart';

// Keep the real localhost HTTP transfer, and control only the boundary between
// completed network IO and the service's asynchronous integrity verification.
class DownloadBoundaryDio extends DioForNative {
  final firstNetworkFinished = Completer<void>();
  final releaseFirst = Completer<void>();
  bool cancelOnCompletion = false;
  int _downloads = 0;

  @override
  Future<Response<dynamic>> download(
    String urlPath,
    dynamic savePath, {
    ProgressCallback? onReceiveProgress,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    bool deleteOnError = true,
    FileAccessMode fileAccessMode = FileAccessMode.write,
    String lengthHeader = Headers.contentLengthHeader,
    Object? data,
    Options? options,
  }) async {
    final ordinal = ++_downloads;
    final response = await super.download(
      urlPath,
      savePath,
      onReceiveProgress: onReceiveProgress,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      deleteOnError: deleteOnError,
      fileAccessMode: fileAccessMode,
      lengthHeader: lengthHeader,
      data: data,
      options: options,
    );
    if (cancelOnCompletion) {
      cancelToken!.cancel('cancel after HTTP transfer');
    } else if (ordinal == 1) {
      firstNetworkFinished.complete();
      await releaseFirst.future;
      if (cancelToken?.isCancelled == true) throw cancelToken!.cancelError!;
    }
    return response;
  }
}

void main() {
  Future<
    ({
      UpdateService service,
      AppRelease release,
      ReleaseAsset asset,
      Directory directory,
    })
  >
  fixture(Dio dio) async {
    final bytes = utf8.encode('isolated real download fixture');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final directory = await Directory.systemTemp.createTemp(
      'update-lifecycle-',
    );
    addTearDown(() async {
      await server.close(force: true);
      await directory.delete(recursive: true);
      dio.close(force: true);
    });
    server.listen((request) {
      request.response
        ..contentLength = bytes.length
        ..add(bytes)
        ..close();
    });
    final asset = ReleaseAsset(
      name: 'SakuraMusic-macos.zip',
      downloadUrl: Uri.parse('http://127.0.0.1:${server.port}/package.zip'),
      sizeBytes: bytes.length,
      sha256: sha256.convert(bytes).toString(),
    );
    final release = AppRelease(
      version: '1.0.0',
      tagName: 'v1.0.0',
      notes: '',
      pageUrl: Uri.parse('https://example.com/release'),
      publishedAt: null,
      assets: [asset],
    );
    return (
      service: UpdateService(
        dio: dio,
        temporaryDirectoryLoader: () async => directory,
      ),
      release: release,
      asset: asset,
      directory: directory,
    );
  }

  test(
    'old cancelled download cleanup cannot delete a completed retry',
    () async {
      final dio = DownloadBoundaryDio();
      final f = await fixture(dio);
      final token = CancelToken();
      final old = f.service.downloadUpdate(
        f.release,
        f.asset,
        cancelToken: token,
      );
      final oldFailed = expectLater(old, throwsA(isA<DioException>()));
      await dio.firstNetworkFinished.future;
      token.cancel('cancel and retry');
      final retry = await f.service.downloadUpdate(f.release, f.asset);
      dio.releaseFirst.complete();
      await oldFailed;
      expect(await retry.exists(), isTrue);
      expect(await retry.readAsString(), 'isolated real download fixture');
      expect(retry.path, endsWith('.zip'));
      final files = await Directory(
        '${f.directory.path}/updates',
      ).list(recursive: true).where((entry) => entry is File).toList();
      expect(files.map((entry) => entry.path), [retry.path]);
    },
  );

  test(
    'cancel after completed HTTP transfer rejects and removes verified package',
    () async {
      final dio = DownloadBoundaryDio()..cancelOnCompletion = true;
      final f = await fixture(dio);
      await expectLater(
        f.service.downloadUpdate(
          f.release,
          f.asset,
          cancelToken: CancelToken(),
        ),
        throwsA(isA<DioException>()),
      );
      final files = await Directory(
        '${f.directory.path}/updates',
      ).list(recursive: true).where((entry) => entry is File).toList();
      expect(files, isEmpty);
    },
  );
}
