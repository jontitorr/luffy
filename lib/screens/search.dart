import "package:flutter/material.dart";
import "package:luffy/api/anilist.dart";
import "package:luffy/components/anime_card.dart";
import "package:luffy/screens/debounce.dart";

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with AutomaticKeepAliveClientMixin {
  final _controller = TextEditingController();
  final _debouncer = Debouncer(delay: const Duration(milliseconds: 500));
  Future<List<SearchResult>?>? _searchResultsFuture;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          titleSpacing: 0,
          title: TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: "Search",
              border: InputBorder.none,
              suffixIcon: IconButton(
                onPressed: _controller.clear,
                icon: const Icon(Icons.clear),
              ),
            ),
            onChanged: (value) {
              if (value.isEmpty) {
                return;
              }

              _debouncer(() {
                setState(() {
                  _searchResultsFuture = AnilistService.search(value);
                });
              });
            },
            onSubmitted: (value) {
              if (value.isEmpty) {
                return;
              }

              setState(() {
                _searchResultsFuture = AnilistService.search(value);
              });
            },
          ),
        ),
        body: Container(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Flexible(
                flex: 10,
                child: SizedBox(
                  height: double.infinity,
                  child: FutureBuilder(
                    future: _searchResultsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.none) {
                        return Container();
                      }

                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      final searchResults = snapshot.data;

                      if (searchResults == null) {
                        return const Center(
                          child: Text("No results found"),
                        );
                      }

                      return GridView.builder(
                        itemCount: searchResults.length,
                        itemBuilder: (context, idx) => AnimeCard(
                          anime: searchResults[idx],
                          width: 120,
                          height: 200,
                          showTitle: true,
                          opensDetails: true,
                        ),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 125,
                          mainAxisExtent: 200,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 24,
                          childAspectRatio: 3 / 2,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
