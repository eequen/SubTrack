import 'package:crypto/crypto.dart';

/// SHA-256 of [bytes] as lowercase hex (AGENTS.md section 8).
String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();
