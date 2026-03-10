import 'package:flutter/material.dart';

/// Shared route observer so screens can react when they become visible again
/// (e.g. tenant dashboard refreshes context when returning from lease manager).
final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();
