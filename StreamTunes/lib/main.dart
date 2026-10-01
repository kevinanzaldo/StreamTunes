import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'state/player_model.dart';
import 'state/library_model.dart';
import 'views/main_navigation_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StreamTunesApp());
}

class StreamTunesApp extends StatefulWidget {
  const StreamTunesApp({super.key});

  @override
  State<StreamTunesApp> createState() => _StreamTunesAppState();
}

class _StreamTunesAppState extends State<StreamTunesApp> {
  late final PlayerModel _playerModel;
  late final LibraryModel _libraryModel;

  @override
  void initState() {
    super.initState();
    _playerModel = PlayerModel();
    _libraryModel = LibraryModel();
  }

  @override
  void dispose() {
    _playerModel.dispose();
    _libraryModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StreamTunes MVP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: MainNavigationShell(
        playerModel: _playerModel,
        libraryModel: _libraryModel,
      ),
    );
  }
}
