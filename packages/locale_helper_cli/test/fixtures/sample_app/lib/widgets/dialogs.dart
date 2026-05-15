import '../main.dart';

class LogoutDialog {
  // logoutConfirm inside AlertDialog — Role.dialog
  Object body(Object context) {
    return _AlertDialog(
      title: _Text(AppLocalizations.of(context).dialogTitle),
      content: _Text(AppLocalizations.of(context).logoutConfirm),
    );
  }
}

class TooltipWidget {
  // Role.tooltip — message parameter
  Object build(Object context) {
    return _Tooltip(
      message: AppLocalizations.of(context).tooltipText,
      child: _Text('?'),
    );
  }
}

class ListWidget {
  // Role.listItem — title in ListTile
  Object build(Object context) {
    return _ListTile(title: _Text(AppLocalizations.of(context).listItemTitle));
  }
}
