import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class MemoryExplorerView extends StatefulWidget {
  const MemoryExplorerView({super.key});

  static final ValueNotifier<String> fileSearchQueryNotifier = ValueNotifier('');

  @override
  State<MemoryExplorerView> createState() => _MemoryExplorerViewState();
}

class _MemoryExplorerViewState extends State<MemoryExplorerView> {
  late String _rootPath;
  late String _currentPath;
  List<FileSystemEntity> _entities = [];
  bool _hasPermission = false;
  bool _loading = false;
  String _errorMessage = '';

  // Real device memory stats
  double _ramTotalGB = 0;
  double _ramUsedGB = 0;
  double _storageTotalGB = 0;
  double _storageUsedGB = 0;
  Timer? _memTimer;

  @override
  void initState() {
    super.initState();
    _rootPath = _getRootPath();
    _currentPath = _rootPath;
    MemoryExplorerView.fileSearchQueryNotifier.addListener(_onSearchChanged);
    _checkAndRequestPermissions();
    _fetchMemoryStats();
    _memTimer = Timer.periodic(const Duration(seconds: 3), (_) => _fetchMemoryStats());
  }

  Future<void> _fetchMemoryStats() async {
    await _fetchRAM();
    await _fetchStorage();
  }

  Future<void> _fetchRAM() async {
    if (!Platform.isAndroid) {
      if (mounted) setState(() { _ramTotalGB = 8.0; _ramUsedGB = 4.2; });
      return;
    }
    try {
      final content = await File('/proc/meminfo').readAsString();
      double memTotal = 0;
      double memAvailable = 0;
      for (final line in content.split('\n')) {
        if (line.startsWith('MemTotal:')) {
          memTotal = double.tryParse(line.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        } else if (line.startsWith('MemAvailable:')) {
          memAvailable = double.tryParse(line.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        }
      }
      final totalGB = memTotal / (1024 * 1024);
      final availGB = memAvailable / (1024 * 1024);
      final usedGB = totalGB - availGB;
      if (mounted) {
        setState(() {
          _ramTotalGB = double.parse(totalGB.toStringAsFixed(1));
          _ramUsedGB = double.parse(usedGB.toStringAsFixed(1));
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchStorage() async {
    try {
      // Use dart:io to get storage stats via statvfs on Android
      final storagePath = Platform.isAndroid ? '/storage/emulated/0' : Directory.current.path;
      final result = await Process.run('df', ['-k', storagePath]);
      if (result.exitCode == 0) {
        final lines = result.stdout.toString().trim().split('\n');
        // Last line contains the stats
        final dataLine = lines.length > 1 ? lines.last : lines.first;
        final parts = dataLine.trim().split(RegExp(r'\s+'));
        if (parts.length >= 4) {
          final totalKB = double.tryParse(parts[1]) ?? 0;
          final usedKB = double.tryParse(parts[2]) ?? 0;
          if (mounted) {
            setState(() {
              _storageTotalGB = double.parse((totalKB / (1024 * 1024)).toStringAsFixed(1));
              _storageUsedGB = double.parse((usedKB / (1024 * 1024)).toStringAsFixed(1));
            });
          }
        }
      }
    } catch (_) {}
  }

  String _getRootPath() {
    if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0');
      if (dir.existsSync()) return dir.path;
      return '/sdcard';
    } else {
      final dir = Directory('C:\\');
      if (dir.existsSync()) return dir.path;
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && Directory(userProfile).existsSync()) return userProfile;
      return Directory.current.path;
    }
  }

  @override
  void dispose() {
    _memTimer?.cancel();
    MemoryExplorerView.fileSearchQueryNotifier.removeListener(_onSearchChanged);
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _checkAndRequestPermissions() async {
    final status = await Permission.storage.status;
    if (!mounted) return;
    if (status.isGranted) {
      setState(() {
        _hasPermission = true;
      });
      _loadPathContents(_currentPath);
    } else {
      final requestResult = await Permission.storage.request();
      if (!mounted) return;
      if (requestResult.isGranted) {
        setState(() {
          _hasPermission = true;
        });
        _loadPathContents(_currentPath);
      } else {
        final manageStatus = await Permission.manageExternalStorage.request();
        if (!mounted) return;
        if (manageStatus.isGranted) {
          setState(() {
            _hasPermission = true;
          });
          _loadPathContents(_currentPath);
        } else {
          // Fallback to read whatever is accessible
          _loadPathContents(_currentPath);
        }
      }
    }
  }

  Future<void> _loadPathContents(String path) async {
    setState(() {
      _loading = true;
      _errorMessage = '';
    });
    try {
      final dir = Directory(path);
      if (dir.existsSync()) {
        final List<FileSystemEntity> list = dir.listSync();
        // Sort: directories first, then files alphabetically
        list.sort((a, b) {
          final aIsDir = a is Directory;
          final bIsDir = b is Directory;
          if (aIsDir && !bIsDir) return -1;
          if (!aIsDir && bIsDir) return 1;
          return a.path.toLowerCase().compareTo(b.path.toLowerCase());
        });
        setState(() {
          _entities = list;
          _currentPath = path;
          _loading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Diretório não existe';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Acesso negado ou erro ao ler diretório: $e';
        _loading = false;
      });
    }
  }

  IconData _getFileIcon(String type) {
    switch (type) {
      case 'PDF':
        return Icons.picture_as_pdf_rounded;
      case 'APK':
        return Icons.android_rounded;
      case 'Imagem':
        return Icons.image_rounded;
      case 'Vídeo':
        return Icons.play_circle_rounded;
      case 'Áudio':
        return Icons.audiotrack_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Widget _buildStorageCard(BuildContext context, bool isDark, ThemeData theme) {
    // Use real device stats; fall back to placeholder if not yet loaded
    final totalSpace = _storageTotalGB > 0 ? _storageTotalGB : 128.0;
    final usedSpace = _storageUsedGB > 0 ? _storageUsedGB : 74.2;
    final progress = (usedSpace / totalSpace).clamp(0.0, 1.0);

    final ramTotal = _ramTotalGB > 0 ? _ramTotalGB : 8.0;
    final ramUsed = _ramUsedGB > 0 ? _ramUsedGB : 4.2;
    final ramAvail = double.parse((ramTotal - ramUsed).toStringAsFixed(1));
    final sysSpace = double.parse((usedSpace * 0.167).toStringAsFixed(1)); // ~system partition estimate

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: (isDark ? Colors.black : Colors.white).withOpacity(0.45),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Memória Interna',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    '${usedSpace.toStringAsFixed(1)} GB / ${totalSpace.toStringAsFixed(0)} GB',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMiniStat('Disponível', '${(totalSpace - usedSpace).toStringAsFixed(1)} GB', theme),
                  _buildMiniStat('Sistema', '${sysSpace.toStringAsFixed(1)} GB', theme),
                  _buildMiniStat('RAM em Uso', '${ramUsed.toStringAsFixed(1)} GB / ${ramTotal.toStringAsFixed(0)} GB', theme),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface.withOpacity(0.45),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface.withOpacity(0.85),
          ),
        ),
      ],
    );
  }

  Widget _buildFileList(ThemeData theme, bool isDark) {
    final query = MemoryExplorerView.fileSearchQueryNotifier.value.toLowerCase().trim();
    final allEntities = _entities;
    final entities = query.isEmpty
        ? allEntities
        : allEntities.where((entity) {
            final name = entity.path.split('/').last.split('\\').last.toLowerCase();
            return name.contains(query);
          }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (_currentPath != _rootPath)
              IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: theme.colorScheme.primary),
                onPressed: () {
                  final parentPath = Directory(_currentPath).parent.path;
                  _loadPathContents(parentPath);
                },
              ),
            Expanded(
              child: Text(
                _currentPath.replaceAll('/storage/emulated/0', 'Memória Interna'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
              : _errorMessage.isNotEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          _errorMessage,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : entities.isEmpty
                      ? Center(
                          child: Text(
                            'Pasta vazia ou sem resultados',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withOpacity(0.4),
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: entities.length,
                          separatorBuilder: (context, index) => Divider(
                            color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
                            height: 1,
                          ),
                          itemBuilder: (context, index) {
                            final entity = entities[index];
                            final isDir = entity is Directory;
                            final name = entity.path.split('/').last.split('\\').last;

                            String sizeStr = '';
                            String dateStr = '';
                            String fileType = 'Documento';
                            if (!isDir) {
                              try {
                                final stat = entity.statSync();
                                final sizeMB = stat.size / (1024 * 1024);
                                sizeStr = sizeMB >= 1.0
                                    ? '${sizeMB.toStringAsFixed(1)} MB'
                                    : '${(stat.size / 1024).toStringAsFixed(0)} KB';
                                final lastMod = stat.modified;
                                dateStr = '${lastMod.day.toString().padLeft(2, '0')}/${lastMod.month.toString().padLeft(2, '0')} ${lastMod.hour.toString().padLeft(2, '0')}:${lastMod.minute.toString().padLeft(2, '0')}';

                                final extension = name.split('.').last.toLowerCase();
                                if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension)) {
                                  fileType = 'Imagem';
                                } else if (['mp4', 'mkv', 'avi', 'mov', '3gp'].contains(extension)) {
                                  fileType = 'Vídeo';
                                } else if (['mp3', 'wav', 'ogg', 'm4a', 'flac'].contains(extension)) {
                                  fileType = 'Áudio';
                                } else if (['pdf'].contains(extension)) {
                                  fileType = 'PDF';
                                } else if (['apk'].contains(extension)) {
                                  fileType = 'APK';
                                }
                              } catch (e) {
                                sizeStr = 'Desconhecido';
                              }
                            }

                            final fileData = {
                              'name': name,
                              'size': sizeStr,
                              'type': isDir ? 'Pasta' : fileType,
                              'date': dateStr,
                              'path': entity.path,
                            };

                            return Dismissible(
                              key: Key(entity.path),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.delete_rounded, color: Colors.white, size: 18),
                              ),
                              onDismissed: (direction) {
                                try {
                                  entity.deleteSync(recursive: true);
                                } catch (e) {
                                  // Ignore delete errors
                                }
                                setState(() {
                                  _entities.removeAt(index);
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('$name excluído'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                              child: InkWell(
                                onTap: () {
                                  if (isDir) {
                                    _loadPathContents(entity.path);
                                  } else {
                                    _showFilePreview(context, fileData, isDark, theme);
                                  }
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isDir
                                              ? Colors.amberAccent.withOpacity(0.12)
                                              : theme.colorScheme.primary.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          isDir ? Icons.folder_open_rounded : _getFileIcon(fileType),
                                          color: isDir ? Colors.amber[700] : theme.colorScheme.primary,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              isDir ? 'Pasta' : '$sizeStr • $dateStr',
                                              style: TextStyle(
                                                fontSize: 9,
                                                color: theme.colorScheme.onSurface.withOpacity(0.4),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isDir)
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          color: theme.colorScheme.onSurface.withOpacity(0.3),
                                          size: 18,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }

  void _showFilePreview(BuildContext context, Map<String, String> file, bool isDark, ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.black : Colors.white).withOpacity(0.7),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getFileIcon(file['type']!),
                        size: 48,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        file['name']!,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tipo: ${file['type']}  •  Tamanho: ${file['size']}\nData: ${file['date']}',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withOpacity(0.55),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Fechar',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0, bottom: 140.0),
      child: Column(
        children: [
          if (_currentPath == _rootPath) _buildStorageCard(context, isDark, theme),
          if (_currentPath == _rootPath) const SizedBox(height: 16),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.black : Colors.white).withOpacity(0.4),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
                      width: 1.2,
                    ),
                  ),
                  child: _buildFileList(theme, isDark),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
