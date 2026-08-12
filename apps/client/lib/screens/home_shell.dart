import 'package:douban_movie/auth/auth_controller.dart';
import 'package:douban_movie/screens/favorites_screen.dart';
import 'package:douban_movie/screens/login_screen.dart';
import 'package:douban_movie/screens/movie_list_screen.dart';
import 'package:douban_movie/state/favorites_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _titles = ['正在热映', '我的收藏'];

  Future<void> _onDestinationSelected(int value) async {
    if (value == 1) {
      final auth = context.read<AuthController>();
      final favorites = context.read<FavoritesController>();
      if (!auth.isLoggedIn) {
        final ok = await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(builder: (_) => const LoginScreen()),
        );
        if (!mounted || ok != true) return;
        await favorites.load();
        if (!mounted) return;
        setState(() => _index = 1);
        return;
      }
      await favorites.load();
      if (!mounted) return;
    }
    setState(() => _index = value);
  }

  Future<void> _logout() async {
    final auth = context.read<AuthController>();
    final favorites = context.read<FavoritesController>();
    await auth.logout();
    favorites.clear();
    if (!mounted) return;
    setState(() => _index = 0);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          if (auth.isLoggedIn)
            IconButton(
              tooltip: '退出登录',
              icon: const Icon(Icons.logout),
              onPressed: _logout,
            ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          MovieListScreen(),
          FavoritesScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_movies_outlined),
            selectedIcon: Icon(Icons.local_movies),
            label: '热映',
          ),
          NavigationDestination(
            icon: Icon(Icons.star_border),
            selectedIcon: Icon(Icons.star),
            label: '收藏',
          ),
        ],
      ),
    );
  }
}
