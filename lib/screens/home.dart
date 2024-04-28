import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:luffy/api/mal.dart";
import "package:luffy/screens/browse.dart";
import "package:luffy/screens/list.dart";
import "package:luffy/screens/search_sources.dart";
import "package:luffy/screens/settings.dart";

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late TabController _tabController;
  late Future<UserInfo?> _userInfoFuture;

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        _currentIndex = _tabController.index;
      });
    }
  }

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 4,
      vsync: this,
    );

    _tabController.addListener(_handleTabChange);
    _userInfoFuture = MalService.getUserInfo();

    if (WidgetsBinding
            .instance.platformDispatcher.views.first.physicalSize.width <
        451) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    if (WidgetsBinding
            .instance.platformDispatcher.views.first.physicalSize.width <
        451) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _userInfoFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final userInfo = snapshot.data;

        return Scaffold(
          body: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              const ListScreen(),
              const BrowseScreen(),
              const SearchScreenSources(),
              SettingsScreen(
                userInfo: userInfo,
              ),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: Theme.of(context).colorScheme.surface,
            currentIndex: _currentIndex,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            selectedFontSize: 10,
            unselectedFontSize: 10,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });

              _tabController.animateTo(index);
            },
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.bookmark_border),
                label: "My Lists",
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.grid_view),
                label: "Browse",
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.search),
                label: "Search All",
              ),
              BottomNavigationBarItem(
                icon: CircleAvatar(
                  backgroundImage: CachedNetworkImageProvider(
                    userInfo?.picture ?? "",
                  ),
                  radius: 12,
                ),
                label: "Account",
              ),
            ],
          ),
        );
      },
    );
  }
}
