import 'dart:async';

import 'package:flutter/material.dart';

class Backdrop extends InheritedWidget {
  final _BackdropScaffoldState data;

  Backdrop({Key key, @required this.data, @required Widget child})
      : super(key: key, child: child);

  static _BackdropScaffoldState of(BuildContext context) =>
      (context.inheritFromWidgetOfExactType(Backdrop) as Backdrop).data;

  @override
  bool updateShouldNotify(Backdrop old) => true;
}

class BackdropScaffold extends StatefulWidget {
  final AnimationController controller;
  final Widget title;
  final Widget backLayer;
  final Widget frontLayer;
  final Widget bottomNavigationBar;
  final List<Widget> actions;
  final double headerHeight;
  final BorderRadius frontLayerBorderRadius;
  final BackdropIconPosition iconPosition;

  BackdropScaffold({
    this.controller,
    this.title,
    this.backLayer,
    this.frontLayer,
    this.actions = const <Widget>[],
    this.headerHeight = 32.0,
    this.frontLayerBorderRadius = const BorderRadius.only(
      topLeft: Radius.circular(16.0),
      topRight: Radius.circular(16.0),
    ),
    this.iconPosition = BackdropIconPosition.leading,
    this.bottomNavigationBar,
  });

  @override
  _BackdropScaffoldState createState() => _BackdropScaffoldState();
}

class _BackdropScaffoldState extends State<BackdropScaffold>
    with SingleTickerProviderStateMixin {
  bool shouldDisposeController = false;
  AnimationController _controller;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  AnimationController get controller => _controller;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      shouldDisposeController = true;
      _controller = AnimationController(
          vsync: this, duration: Duration(milliseconds: 100), value: 1.0);
    } else {
      _controller = widget.controller;
    }
  }

  @override
  void dispose() {
    super.dispose();
    if (shouldDisposeController) {
      _controller.dispose();
    }
  }

  bool get isTopPanelVisible {
    final AnimationStatus status = controller.status;
    return status == AnimationStatus.completed ||
        status == AnimationStatus.forward;
  }

  bool get isBackPanelVisible {
    final AnimationStatus status = controller.status;
    return status == AnimationStatus.dismissed ||
        status == AnimationStatus.reverse;
  }

  void fling() {
    controller.fling(velocity: isTopPanelVisible ? -1.0 : 1.0);
  }

  void showBackLayer() {
    if (isTopPanelVisible) {
      controller.fling(velocity: -1.0);
    }
  }

  void showFrontLayer() {
    if (isBackPanelVisible) {
      controller.fling(velocity: 1.0);
    }
  }

  Animation<RelativeRect> getPanelAnimation(
      BuildContext context, BoxConstraints constraints) {
    final height = constraints.biggest.height;
    final backPanelHeight = height - widget.headerHeight;
    final frontPanelHeight = -backPanelHeight;

    return RelativeRectTween(
      begin: RelativeRect.fromLTRB(0.0, backPanelHeight, 0.0, frontPanelHeight),
      end: RelativeRect.fromLTRB(0.0, 0.0, 0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.linear,
    ));
  }

  Widget _buildInactiveLayer(BuildContext context) {
    return Offstage(
      offstage: isTopPanelVisible,
      child: GestureDetector(
        onTap: () => fling(),
        behavior: HitTestBehavior.opaque,
        child: SizedBox.expand(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade200.withOpacity(0.7),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackPanel() {
    var status = _controller.status;
    return Visibility(
      replacement: SizedBox.expand(),
      visible: status == AnimationStatus.dismissed ||
          status == AnimationStatus.reverse ||
          status == AnimationStatus.forward,
      child: Material(
        color: Theme.of(context).primaryColor,
        child: widget.backLayer,
      ),
    );
  }

  Widget _buildFrontPanel(BuildContext context) {
    return Material(
      elevation: 12.0,
      borderRadius: widget.frontLayerBorderRadius,
      child: Stack(
        children: <Widget>[
          widget.frontLayer,
          _buildInactiveLayer(context),
        ],
      ),
    );
  }

  Future<bool> _willPopCallback(BuildContext context) async {
    if (isBackPanelVisible) {
      showFrontLayer();
      return null;
    }
    return true;
  }

  Widget _buildBody(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _willPopCallback(context),
      child: Scaffold(
        key: scaffoldKey,
        appBar: AppBar(
          title: widget.title,
          actions: widget.iconPosition == BackdropIconPosition.action
              ? <Widget>[BackdropToggleButton()] + widget.actions
              : widget.actions,
          elevation: 0.0,
          leading: widget.iconPosition == BackdropIconPosition.leading
              ? BackdropToggleButton()
              : null,
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              child: Stack(
                children: <Widget>[
                  _buildBackPanel(),
                  PositionedTransition(
                    rect: getPanelAnimation(context, constraints),
                    child: _buildFrontPanel(context),
                  ),
                ],
              ),
            );
          },
        ),
        bottomNavigationBar: widget.bottomNavigationBar,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Backdrop(
      data: this,
      child: Builder(
        builder: (context) => _buildBody(context),
      ),
    );
  }
}

class BackdropToggleButton extends StatelessWidget {
  final AnimatedIconData icon;

  const BackdropToggleButton({
    this.icon = AnimatedIcons.close_menu,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: AnimatedIcon(
        icon: icon,
        progress: Backdrop.of(context).controller.view,
      ),
      onPressed: () {
        //FocusScope.of(context).requestFocus(FocusNode());
        Backdrop.of(context).fling();
      },
    );
  }
}

enum BackdropIconPosition { none, leading, action }
