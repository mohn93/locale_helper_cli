import '../main.dart';

class LoginPage {
  Object build(Object context) {
    // Role.text — appTitle as plain Text widget argument
    final titleText = _Text(AppLocalizations.of(context).appTitle);

    // Role.header — appTitle as AppBar.title named argument
    final appBar = _AppBar(title: _Text(AppLocalizations.of(context).appTitle));

    // Role.fieldLabel — email as InputDecoration.labelText
    final emailField = _TextField(
      decoration: _InputDecoration(
        labelText: AppLocalizations.of(context).email,
        hintText: AppLocalizations.of(context).emailHint,
      ),
    );

    // Role.button — loginButton as ElevatedButton child text
    final loginBtn = _ElevatedButton(
      child: _Text(AppLocalizations.of(context).loginButton),
      onPressed: null,
    );

    return '$titleText $appBar $emailField $loginBtn';
  }
}
