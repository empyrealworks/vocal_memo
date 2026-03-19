// lib/env/env.dart
import 'package:envied/envied.dart';

part 'env.g.dart';

// ⚠️ IMPORTANT: We use a fixed obfuscationSeed to ensure that the 
// generated encryption key remains stable across different builds 
// and environments. Without this, the key might change when 
// build_runner is executed, making existing data undecryptable.
@Envied(path: '.env', obfuscate: true, randomSeed: 42)
abstract class Env {
  @EnviedField(varName: 'GEMINI_API_KEY')
  static final String geminiApiKey = _Env.geminiApiKey;
  
  @EnviedField(varName: 'GEMINI_MODEL')
  static final String geminiModel = _Env.geminiModel;
  
  @EnviedField(varName: 'ENCRYPTION_KEY')
  static final String encryptionKey = _Env.encryptionKey;
}