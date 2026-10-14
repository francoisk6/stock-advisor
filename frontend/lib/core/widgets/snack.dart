import 'package:flutter/material.dart';

/// Shows [text] right away, replacing any message still on screen (no queueing).
void showSnack(ScaffoldMessengerState messenger, String text) => messenger
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(text)));
