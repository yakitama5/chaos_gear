import 'dart:io';

// テンプレートのリポジトリ名（置換元）
// 現在のプロジェクト名（pubspec.yaml の name）に合わせて設定してください。
const String oldName = 'chaos_gear';

// 除外するディレクトリ（処理速度向上と破壊防止）
const List<String> excludeDirs = [
  '.git',
  '.dart_tool',
  'build',
  '.idea',
  '.vscode',
  'macos/Flutter/ephemeral',
  'ios/Pods',
];

void main(List<String> args) {
  if (args.isEmpty) {
    print('❌ エラー: 新しいプロジェクト名を指定してください。');
    print('💡 使い方: dart run scripts/rename_project.dart <new_project_name>');
    exit(1);
  }

  final newName = args.first;
  print('🚀 [$oldName] を [$newName] に一括置換・リネームします...\n');

  final currentDir = Directory.current;

  // 全てのエンティティを事前にリストアップ
  final allEntities = currentDir.listSync(recursive: true, followLinks: false);

  // 1. ファイル内の文字列を置換
  int updatedContentCount = 0;
  for (var entity in allEntities) {
    if (_shouldExclude(entity.path)) continue;

    if (entity is File) {
      try {
        final content = entity.readAsStringSync();
        if (content.contains(oldName)) {
          final newContent = content.replaceAll(oldName, newName);
          entity.writeAsStringSync(newContent);
          print('📝 内容更新: ${entity.path}');
          updatedContentCount++;
        }
      } catch (e) {
        // バイナリファイル（画像など）は読み込みエラーになるのでスキップ
        continue;
      }
    }
  }

  // 2. ファイル名・ディレクトリ名自体のリネーム
  // 名前に oldName を含むものを抽出
  final entitiesToRename = allEntities.where((entity) {
    if (_shouldExclude(entity.path)) return false;
    
    // スクリプト自身はリネーム対象から除外
    if (entity.path == Platform.script.toFilePath()) return false;

    final baseName = _getBasename(entity.path);
    return baseName.contains(oldName);
  }).toList();

  // 深い階層から順にリネームするためにパス長で降順ソート
  // これにより、親ディレクトリをリネームする前に子要素のリネームが完了する
  entitiesToRename.sort((a, b) => b.path.length.compareTo(a.path.length));

  int renamedCount = 0;
  for (var entity in entitiesToRename) {
    final parentPath = entity.parent.path;
    final oldBaseName = _getBasename(entity.path);
    final newBaseName = oldBaseName.replaceAll(oldName, newName);
    
    // 新しいパスを構築
    final newPath = '$parentPath${Platform.pathSeparator}$newBaseName';

    try {
      entity.renameSync(newPath);
      print('📁 リネーム: ${entity.path} -> $newPath');
      renamedCount++;
    } catch (e) {
      print('⚠️ リネーム失敗: ${entity.path} (エラー: $e)');
    }
  }

  print('\n🎉 完了しました！');
  print('   - 内容を更新したファイル: $updatedContentCount 件');
  print('   - リネームしたファイル/ディレクトリ: $renamedCount 件');
  print('\n💡 次のアクション: `flutter clean` と `flutter pub get` を実行して環境を整えてください。');
}

// パスからファイル名/ディレクトリ名のみを取得
String _getBasename(String path) {
  // Windows と POSIX 両方の区切り文字に対応
  return path.split(RegExp(r'[/\\]')).last;
}

// 除外ディレクトリに含まれているか判定
bool _shouldExclude(String path) {
  final normalizedPath = path.replaceAll('\\', '/');
  for (var exclude in excludeDirs) {
    if (normalizedPath.contains('/$exclude/') ||
        normalizedPath.endsWith('/$exclude')) {
      return true;
    }
  }
  return false;
}
