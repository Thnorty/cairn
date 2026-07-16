import 'package:cairn/src/services/app_settings_opener.dart';
import 'package:cairn/src/services/recent_photo_library.dart';

/// In-memory [RecentPhotoLibrary] for widget tests: never touches
/// `photo_manager`'s platform channel, which `flutter test` cannot exercise.
/// A test configures [result] (defaulting to no access, matching the
/// "photo access denied" case) and, when serving a
/// [RecentPhotosLoaded] list, [filePaths] mapping each asset id to the file
/// path [filePathFor] should resolve to.
class FakeRecentPhotoLibrary implements RecentPhotoLibrary {
  FakeRecentPhotoLibrary({
    RecentPhotosResult result = const RecentPhotosUnavailable(),
    Map<String, String>? filePaths,
  })  : _result = result,
        _filePaths = filePaths ?? const {};

  RecentPhotosResult _result;
  final Map<String, String> _filePaths;

  int loadCalls = 0;
  int filePathForCalls = 0;

  /// Lets a test swap the result after construction (e.g. simulate the
  /// asset vanishing between the grid load and a tap).
  void setResult(RecentPhotosResult result) => _result = result;

  @override
  Future<RecentPhotosResult> loadRecent({required int count}) async {
    loadCalls++;
    return _result;
  }

  @override
  Future<String?> filePathFor(String assetId) async {
    filePathForCalls++;
    return _filePaths[assetId];
  }
}

/// In-memory [AppSettingsOpener] for widget tests: never touches
/// `permission_handler`'s platform channel.
class FakeAppSettingsOpener implements AppSettingsOpener {
  int openCalls = 0;

  @override
  Future<void> openCameraSettings() async {
    openCalls++;
  }
}
