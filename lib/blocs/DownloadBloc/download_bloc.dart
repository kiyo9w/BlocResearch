import 'package:bloc/bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../utils/file_utils.dart';
import 'package:migrated/models/file_info.dart';
import 'package:flutter_downloader/flutter_downloader.dart';

part 'download_event.dart';
part 'download_state.dart';

class DownloadBloc extends Bloc<DownloadEvent, DownloadState> {
  final FileRepository fileRepository;

  DownloadBloc({required this.fileRepository}) : super(DownloadIdle()) {
    on<StartDownload>(_onStartDownload);
    on<CheckDownloadStatus>(_onCheckDownloadStatus);
  }

  Future<void> _onStartDownload(StartDownload event, Emitter<DownloadState> emit) async {
    emit(DownloadInProgress(progress: 0.0, message: 'Starting download...'));

    final dir = await getApplicationDocumentsDirectory();
    final savedDir = dir.path;

    final taskId = await FlutterDownloader.enqueue(
      url: event.url,
      savedDir: savedDir,
      fileName: event.fileName,
      showNotification: true,
      openFileFromNotification: true,
    );

    if (taskId != null) {
      emit(DownloadInProgress(progress: 0.0, message: 'Download in progress...', taskId: taskId));
    } else {
      emit(DownloadFailed(error: 'Failed to start download'));
    }
  }

  Future<void> _onCheckDownloadStatus(CheckDownloadStatus event, Emitter<DownloadState> emit) async {
    final tasks = await FlutterDownloader.loadTasks();
    if (tasks != null) {
      final matchedTasks = tasks.where((task) => task.taskId == event.taskId);
      final currentTask = matchedTasks.isNotEmpty ? matchedTasks.first : null;

      if (currentTask != null) {
        if (currentTask.status == DownloadTaskStatus.complete) {
          final filePath = currentTask.savedDir + '/' + (currentTask.filename ?? 'downloaded_file');
          final file = File(filePath);
          if (await file.exists()) {
            final fileSize = await file.length();
            await fileRepository.saveFiles([FileInfo(filePath, fileSize)]);
            emit(DownloadCompleted(filePath: filePath));
          } else {
            emit(DownloadFailed(error: 'File not found after download!'));
          }
        } else if (currentTask.status == DownloadTaskStatus.failed) {
          emit(DownloadFailed(error: 'Download failed'));
        } else if (currentTask.status == DownloadTaskStatus.running) {
          emit(DownloadInProgress(progress: currentTask.progress / 100.0, message: 'Downloading...', taskId: currentTask.taskId));
        }
      }
    }
  }
}