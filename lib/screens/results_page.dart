import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:migrated/screens/search_screen.dart';
import 'package:migrated/services/annas_archieve.dart';
import 'package:migrated/services/webview.dart';
import 'package:migrated/depeninject/injection.dart';
import 'package:migrated/blocs/FileBloc/file_bloc.dart';
import 'package:migrated/widgets/file_card.dart';
import 'package:migrated/widgets/page_title_widget.dart';
import 'package:migrated/widgets/book_info_widget.dart';

class ResultPage extends StatefulWidget {
  final String searchQuery;

  const ResultPage({Key? key, required this.searchQuery}) : super(key: key);

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  bool _isShowingDownloadDialog = false;
  late final FileBloc _fileBloc;
  late final AnnasArchieve annasArchieve;

  @override
  void initState() {
    super.initState();
    _fileBloc = getIt<FileBloc>();
    annasArchieve = getIt<AnnasArchieve>();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FileBloc, FileState>(
      bloc: _fileBloc,
      listener: (context, state) async {
        if (state is FileError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        } else if (state is FileViewing) {
          Navigator.pushNamed(context, '/viewer').then((_) {
            Navigator.pop(context);
          });
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(80),
            child: AppBar(
              backgroundColor: Colors.white,
              centerTitle: false,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  _fileBloc.add(CloseViewer());
                  Navigator.pop(context);
                },
              ),
              title: const Text(
                'Result',
                style: TextStyle(
                  fontSize: 42.0,
                ),
              ),
            ),
          ),
          body: BlocConsumer<FileBloc, FileState>(
            bloc: _fileBloc,
            listener: (context, state) {
              if (state is FileError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.message)),
                );
              }
            },
            builder: (context, state) {
              if (state is FileSearchLoading) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(left: 5, right: 5, top: 10),
                      child: TitleText("Results for \"" + widget.searchQuery +"\""),
                    ),
                    const Expanded(
                      child: Center(
                        child: SizedBox(
                          width: 25,
                          height: 25,
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),
                  ],
                );
              } else if (state is FileSearchResults) {
                final data = state.books;
                if (data.isNotEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 5, right: 5, top: 10),
                    child: CustomScrollView(
                      slivers: <Widget>[
                        SliverToBoxAdapter(
                          child: TitleText("Results for \"" + widget.searchQuery +"\""),
                        ),
                        SliverList(
                          delegate: SliverChildListDelegate(
                            data.map((book) {
                              return FileCard(
                                filePath: book.link,
                                fileSize: 0,
                                isSelected: false,
                                onSelected: () {
                                  _fileBloc.add(SelectFile(book.link));
                                },
                                onView: () {
                                  _handleBookClick(book.link);
                                },
                                onRemove: () {},
                                onDownload: () async {
                                  // final mirrorLink = await Navigator.push(
                                  //   context,
                                  //   MaterialPageRoute(
                                  //     builder: (context) =>
                                  //         WebviewPage(url: book.link),
                                  //   ),
                                  // );
                                  final mirrorLink = 'https://prothoughts.co.in/wp-content/uploads/2022/06/a-guide-to-the-project-management-body-of-knowledge-6e.pdf';
                                  if (mirrorLink != null && mirrorLink is String) {
                                    _fileBloc.add(DownloadFile(
                                        url: mirrorLink, fileName: book.title + ".pdf"));
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                          Text('Failed to get download link')),
                                    );
                                  }
                                },
                                title: book.title,
                                isInternetBook: true,
                                author: book.author,
                                thumbnailUrl: book.thumbnail,
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 30),
                        Text(
                          "No Results Found!",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  );
                }
              } else if (state is FileError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Error: ${state.message}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          _fileBloc.add(SearchBooks(query: widget.searchQuery));
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              } else {
                print('$state');
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        style: TextStyle(fontSize: 16),
                        '$state',
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }

  Future<void> _handleBookClick(String url) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final bookInfo = await annasArchieve.bookInfo(url: url);

      Navigator.of(context).pop();

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: BookInfoWidget(
              genre: AnnasArchieve.getGenreFromInfo(bookInfo.info!),
              thumbnailUrl: bookInfo.thumbnail,
              author: bookInfo.author,
              link: bookInfo.link,
              description: bookInfo.description,
              fileSize: AnnasArchieve.getFileSizeFromInfo(bookInfo.info!),
              title: bookInfo.title,
              ratings: 4,
              language: AnnasArchieve.getLanguageFromInfo(bookInfo.info!),
              onDownload: () async {
                final mirrorLink = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WebviewPage(url: bookInfo.link),
                  ),
                );

                if (mirrorLink != null && mirrorLink is String) {
                  BlocProvider.of<FileBloc>(context).add(
                    DownloadFile(url: mirrorLink, fileName: bookInfo.title),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Failed to get download link')),
                  );
                }
              },
            ),
          );
        },
      );
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading book info: $e')),
      );
    }
  }
}

class DownloadProgressDialog extends StatelessWidget {
  final double progress;

  const DownloadProgressDialog({Key? key, required this.progress})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final percentage = (progress * 100).toStringAsFixed(0);
    return AlertDialog(
      title: Text('Downloading...'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(value: progress),
          SizedBox(height: 10),
          Text('$percentage%'),
        ],
      ),
    );
  }
}