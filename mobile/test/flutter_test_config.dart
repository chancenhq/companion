import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';

Future<void> testExecutable(Future<void> Function() testMain) {
  return AlchemistConfig.runWithConfig(
    config: AlchemistConfig(
      theme: ThemeData(useMaterial3: true),
      ciGoldensConfig: AlchemistConfig.current().ciGoldensConfig.copyWith(
            enabled: false,
            filePathResolver: _linuxGoldenFile,
          ),
      platformGoldensConfig:
          AlchemistConfig.current().platformGoldensConfig.copyWith(
                filePathResolver: _linuxGoldenFile,
                platforms: {HostPlatform.linux},
              ),
    ),
    run: testMain,
  );
}

FutureOr<String> _linuxGoldenFile(
  String fileName,
  String environmentName,
) {
  return 'goldens/linux/$fileName.png';
}
