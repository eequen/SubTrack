import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:subtrack/core/format.dart';
import 'package:subtrack/core/hashing.dart';
import 'package:subtrack/core/mime.dart';
import 'package:subtrack/data/storage/blob_store.dart';

Uint8List bytesOf(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  test('sha256Hex matches the known vector for "abc"', () {
    expect(
      sha256Hex(utf8.encode('abc')),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });

  test('mimeForName covers common types and falls back safely', () {
    expect(mimeForName('report.PDF'), 'application/pdf');
    expect(mimeForName('notes.txt'), 'text/plain');
    expect(mimeForName('photo.jpg'), 'image/jpeg');
    expect(mimeForName('archive.zip'), 'application/zip');
    expect(mimeForName('weird.xyz'), 'application/octet-stream');
    expect(mimeForName('noextension'), 'application/octet-stream');
  });

  test('formatBytes produces readable sizes', () {
    expect(formatBytes(0), '0 B');
    expect(formatBytes(512), '512 B');
    expect(formatBytes(1536), '1.5 KB');
    expect(formatBytes(1024 * 100), '100 KB');
    expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
  });

  group('BlobStore', () {
    late Directory tmp;
    late BlobStore store;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('subtrack_blob_test');
      store = BlobStore(Future.value(tmp));
    });

    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    test('same content twice stores one blob named by its hash', () async {
      final first = await store.saveBytes(bytesOf('hello world'));
      final second = await store.saveBytes(bytesOf('hello world'));

      expect(first, second);
      expect(first, sha256Hex(utf8.encode('hello world')));
      final blobs = Directory(p.join(tmp.path, 'blobs'));
      expect(await blobs.list().length, 1);
      expect(await store.exists(first), isTrue);
      expect(await store.read(first), utf8.encode('hello world'));
    });

    test('different content stores separate blobs', () async {
      await store.saveBytes(bytesOf('one'));
      await store.saveBytes(bytesOf('two'));
      final blobs = Directory(p.join(tmp.path, 'blobs'));
      expect(await blobs.list().length, 2);
    });

    test('exportForOpening copies the blob with the display name', () async {
      final hash = await store.saveBytes(bytesOf('pdf bytes'));
      final exported = await store.exportForOpening(hash, 'my report.pdf');

      expect(await exported.exists(), isTrue);
      expect(p.basename(exported.path), startsWith(hash.substring(0, 8)));
      expect(exported.path, endsWith('_my report.pdf'));
      expect(await exported.readAsBytes(), utf8.encode('pdf bytes'));
    });
  });
}
