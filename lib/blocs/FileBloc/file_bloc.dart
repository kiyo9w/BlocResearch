import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'dart:io';
import 'package:migrated/models/file_info.dart';
import 'package:migrated/utils/file_utils.dart';
import 'package:migrated/services/storage_scanner_service.dart';

part 'file_event.dart';
part 'file_state.dart';

class FileBloc extends Bloc<FileEvent, FileState> {
  final FileRepository fileRepository;
  final StorageScannerService storageScannerService;

  FileBloc({
    required this.fileRepository,
    required this.storageScannerService,
  }) : super(FileInitial()) {
    on<InitFiles>(_onInitFiles);
    on<LoadFile>(_onLoadFile);
    on<SelectFile>(_onSelectFile);
    on<ViewFile>(_onViewFile);
    on<RemoveFile>(_onRemoveFile);
    on<CloseViewer>(_onCloseViewer);
    on<ToggleStarred>(_onToggleStarred);
    on<ScanStorage>(_onScanStorage);
  }

  Future<void> _onInitFiles(InitFiles event, Emitter<FileState> emit) async {
    final savedFiles = await fileRepository.loadFiles();
    print(savedFiles.toString());
    if (savedFiles.isNotEmpty) {
      emit(FileLoaded(savedFiles));
    } else {
      emit(FileInitial());
    }
  }

  Future<void> _onLoadFile(LoadFile event, Emitter<FileState> emit) async {
    try {
      final filePath = event.filePath;
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File doesn\'t exist');
      }
      final fileSize = await file.length();

      List<FileInfo> currentFiles = [];
      if (state is FileLoaded) {
        currentFiles = (state as FileLoaded).files;
      }

      final isFileAlreadyLoaded =
          currentFiles.any((existingFile) => existingFile.filePath == filePath);
      if (isFileAlreadyLoaded) {
        emit(FileLoaded(currentFiles));
      } else {
        final newFiles = [...currentFiles, FileInfo(filePath, fileSize)];
        emit(FileLoaded(newFiles));
        await fileRepository.saveFiles(newFiles);
      }
    } catch (e) {
      emit(FileError(message: e.toString()));
    }
  }

  Future<void> _onSelectFile(SelectFile event, Emitter<FileState> emit) async {
    if (state is FileLoaded) {
      final currentState = state as FileLoaded;
      final updatedFiles = currentState.files.map((file) {
        if (file.filePath == event.filePath) {
          return file.copyWith(isSelected: !file.isSelected);
        }
        return file;
      }).toList();

      emit(FileLoaded(updatedFiles));
      await fileRepository.saveFiles(updatedFiles);
    }
  }

  void _onViewFile(ViewFile event, Emitter<FileState> emit) async {
    if (state is FileLoaded) {
      final currentState = state as FileLoaded;
      final fileToView = currentState.files.firstWhere(
        (file) => file.filePath == event.filePath,
        orElse: () => currentState.files.first,
      );

      final updatedFiles = currentState.files.map((file) {
        if (file.filePath == event.filePath) {
          return file.copyWith(wasRead: true);
        }
        return file.copyWith(wasRead: false);
      }).toList();

      await fileRepository.saveFiles(updatedFiles);
      emit(FileViewing(updatedFiles, fileToView.filePath));
    }
  }

  Future<void> _onRemoveFile(RemoveFile event, Emitter<FileState> emit) async {
    if (state is FileLoaded) {
      final currentFiles = (state as FileLoaded).files;
      final updatedFiles = currentFiles
          .where((file) => file.filePath != event.filePath)
          .toList();

      if (updatedFiles.isEmpty) {
        emit(FileInitial());
        await fileRepository.saveFiles([]);
      } else {
        emit(FileLoaded(updatedFiles));
        await fileRepository.saveFiles(updatedFiles);
      }
    }
  }

  void _onCloseViewer(CloseViewer event, Emitter<FileState> emit) {
    if (state is FileViewing) {
      final fileViewingState = state as FileViewing;
      emit(FileLoaded(fileViewingState.files));
    }
  }

  Future<void> _onToggleStarred(
      ToggleStarred event, Emitter<FileState> emit) async {
    if (state is FileLoaded) {
      final currentState = state as FileLoaded;
      final updatedFiles = currentState.files.map((file) {
        if (file.filePath == event.filePath) {
          return file.copyWith(isStarred: !file.isStarred);
        }
        return file;
      }).toList();

      emit(FileLoaded(updatedFiles));
      await fileRepository.saveFiles(updatedFiles);
    }
  }

  Future<void> _onScanStorage(
      ScanStorage event, Emitter<FileState> emit) async {
    try {
      emit(FileScanning());
      final discoveredFiles = await storageScannerService.scanStorage();

      List<FileInfo> currentFiles = [];
      if (state is FileLoaded) {
        currentFiles = (state as FileLoaded).files;
      }

      final Set<String> existingPaths =
          currentFiles.map((f) => f.filePath).toSet();
      final newFiles = [
        ...currentFiles,
        ...discoveredFiles
            .where((file) => !existingPaths.contains(file.filePath))
      ];

      emit(FileLoaded(newFiles));
      await fileRepository.saveFiles(newFiles);
    } catch (e) {
      emit(FileError(message: 'Storage scanning failed: ${e.toString()}'));
    }
  }
}
