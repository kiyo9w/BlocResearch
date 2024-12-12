part of 'file_bloc.dart';

abstract class FileEvent extends Equatable {
  const FileEvent();

  @override
  List<Object> get props => [];
}

class LoadFile extends FileEvent {
  final String filePath;

  const LoadFile(this.filePath);

  @override
  List<Object> get props => [filePath];
}

class SelectFile extends FileEvent {
  final String filePath;

  const SelectFile(this.filePath);

  @override
  List<Object> get props => [filePath];
}

class ViewFile extends FileEvent {
  final String filePath;

  const ViewFile(this.filePath);

  @override
  List<Object> get props => [filePath];
}

class RemoveFile extends FileEvent {
  final String filePath;

  const RemoveFile(this.filePath);

  @override
  List<Object> get props => [filePath];
}