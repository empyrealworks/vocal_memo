// lib/env/env.dart
import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env')
abstract class Env {
  @EnviedField(varName: 'GEMINI_API_KEY', obfuscate: true)
  static final String geminiApiKey = _Env.geminiApiKey;
  @EnviedField(varName: 'GEMINI_MODEL', obfuscate: true)
  static final String geminiModel = _Env.geminiModel;
}