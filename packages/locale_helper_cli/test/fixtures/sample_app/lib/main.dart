class AppLocalizations {
  static AppLocalizations of(Object context) => AppLocalizations();
  String get appTitle => '';
  String get loginButton => '';
  String get logoutConfirm => '';
  String get email => '';
  String get emailHint => '';
  String get dialogTitle => '';
  String get tooltipText => '';
  String get listItemTitle => '';
}

// Shim widget classes — no Flutter dependency.
class _Text {
  _Text(String data);
}

class _InputDecoration {
  _InputDecoration({String? labelText, String? hintText});
}

class _TextField {
  _TextField({_InputDecoration? decoration});
}

class _AppBar {
  _AppBar({Object? title});
}

class _ElevatedButton {
  _ElevatedButton({Object? child, Object? onPressed});
}

class _AlertDialog {
  _AlertDialog({Object? title, Object? content});
}

class _SnackBar {
  _SnackBar({Object? content});
}

class _Tooltip {
  _Tooltip({String? message, Object? child});
}

class _ListTile {
  _ListTile({Object? title, Object? subtitle});
}
