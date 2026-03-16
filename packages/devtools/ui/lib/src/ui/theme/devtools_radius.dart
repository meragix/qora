import 'package:flutter/material.dart';

/// DevTools border-radius tokens.
class DevtoolsRadius {
  DevtoolsRadius._();

  static const double sm = 4;
  static const double md = 6;
  static const double lg = 8;

  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
}
