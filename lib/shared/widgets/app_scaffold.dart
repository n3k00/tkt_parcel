import 'package:flutter/material.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.drawer,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.appBarBackgroundColor,
    this.appBarForegroundColor,
    this.isBlocking = false,
    this.blockingOverlay,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;
  final Widget? drawer;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Color? appBarBackgroundColor;
  final Color? appBarForegroundColor;
  final bool isBlocking;
  final Widget? blockingOverlay;

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      drawer: drawer,
      appBar: AppBar(
        automaticallyImplyLeading: !isBlocking,
        title: Text(title),
        actions: isBlocking ? const [] : actions,
        backgroundColor: appBarBackgroundColor,
        foregroundColor: appBarForegroundColor,
      ),
      body: body,
      floatingActionButton: isBlocking ? null : floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
    );

    return PopScope(
      canPop: !isBlocking,
      child: Stack(
        children: [
          scaffold,
          if (isBlocking)
            Positioned.fill(
              child:
                  blockingOverlay ??
                  ColoredBox(
                    color: Colors.black26,
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
            ),
        ],
      ),
    );
  }
}
