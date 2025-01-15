import 'package:another_flushbar/flushbar.dart';
import 'package:cake_wallet/core/execution_state.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/screens/auth/auth_page.dart';
import 'package:cake_wallet/src/screens/wallet_unlock/wallet_unlock_arguments.dart';
import 'package:cake_wallet/src/widgets/primary_button.dart';
import 'package:cake_wallet/themes/extensions/cake_text_theme.dart';
import 'package:cake_wallet/themes/extensions/new_wallet_theme.dart';
import 'package:cake_wallet/utils/responsive_layout_util.dart';
import 'package:cake_wallet/utils/show_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cake_wallet/view_model/wallet_unlock_view_model.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';

class WalletUnlockPage extends StatefulWidget {
  WalletUnlockPage(
      this.walletUnlockViewModel, this.onAuthenticationFinished, this.authPasswordHandler,
      {required this.closable});

  final WalletUnlockViewModel walletUnlockViewModel;
  final OnAuthenticationFinished onAuthenticationFinished;
  final AuthPasswordHandler? authPasswordHandler;
  final bool closable;

  @override
  State<StatefulWidget> createState() => WalletUnlockPageState();
}

class WalletUnlockPageState extends AuthPageState<WalletUnlockPage> {
  WalletUnlockPageState() : _passwordController = TextEditingController();

  final TextEditingController _passwordController;
  final _key = GlobalKey<ScaffoldState>();
  final _backArrowImageDarkTheme = Image.asset('assets/images/close_button.png');
  ReactionDisposer? _reaction;
  Flushbar<void>? _authBar;
  Flushbar<void>? _progressBar;
  void Function()? _passwordControllerListener;

  @override
  void initState() {
    _reaction ??= reaction((_) => widget.walletUnlockViewModel.state, (ExecutionState state) {
      if (state is ExecutedSuccessfullyState) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onAuthenticationFinished(true, this);
        });
        setState(() {});
      }

      if (state is IsExecutingState) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // null duration to make it indefinite until its disposed
          _authBar = createBar<void>(S.of(context).authentication, duration: null)..show(context);
        });
      }

      if (state is FailureState) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          dismissFlushBar(_authBar);
          showBar<void>(context, S.of(context).failed_authentication(state.error));

          widget.onAuthenticationFinished(false, this);
        });
      }
    });

    _passwordControllerListener =
        () => widget.walletUnlockViewModel.setPassword(_passwordController.text);

    if (_passwordControllerListener != null) {
      _passwordController.addListener(_passwordControllerListener!);
    }

    super.initState();
  }

  @override
  void dispose() {
    _reaction?.reaction.dispose();

    if (_passwordControllerListener != null) {
      _passwordController.removeListener(_passwordControllerListener!);
    }

    super.dispose();
  }

  @override
  void changeProcessText(String text) {
    dismissFlushBar(_authBar);
    _progressBar = createBar<void>(text, duration: null)..show(_key.currentContext!);
  }

  @override
  void hideProgressText() {
    dismissFlushBar(_progressBar);
    _progressBar = null;
  }

  void dismissFlushBar(Flushbar<dynamic>? bar) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await bar?.dismiss();
    });
  }

  @override
  Future<void> close({String? route, arguments}) async {
    if (_key.currentContext == null) {
      throw Exception('Key context is null. Should be not happened');
    }

    /// not the best scenario, but WidgetsBinding is not behaving correctly on Android
    await Future<void>.delayed(Duration(milliseconds: 50));
    await _authBar?.dismiss();
    await Future<void>.delayed(Duration(milliseconds: 50));
    await _progressBar?.dismiss();
    await Future<void>.delayed(Duration(milliseconds: 50));
    if (route != null) {
      Navigator.of(_key.currentContext!).pushReplacementNamed(route, arguments: arguments);
    } else {
      Navigator.of(_key.currentContext!).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _key,
      appBar: CupertinoNavigationBar(
          leading: widget.closable
              ? Container(
                  padding: EdgeInsets.only(top: 10),
                  child: SizedBox(
                    height: 37,
                    width: 37,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      child: _backArrowImageDarkTheme,
                    ),
                  ))
              : Container(),
          backgroundColor: Theme.of(context).colorScheme.background,
          border: null),
      resizeToAvoidBottomInset: false,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: ResponsiveLayoutUtilBase.kDesktopMaxWidthConstraint,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      widget.walletUnlockViewModel.walletName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).extension<CakeTextTheme>()!.titleColor,
                      ),
                    ),
                    SizedBox(height: 24),
                    Form(
                      child: TextFormField(
                        key: ValueKey('enter_wallet_password'),
                        onChanged: (value) => null,
                        controller: _passwordController,
                        textAlign: TextAlign.center,
                        obscureText: true,
                        style: TextStyle(
                          fontSize: 20.0,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).extension<CakeTextTheme>()!.titleColor,
                        ),
                        decoration: InputDecoration(
                          hintStyle: TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).extension<NewWalletTheme>()!.hintTextColor,
                          ),
                          hintText: S.of(context).enter_wallet_password,
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Theme.of(context).extension<NewWalletTheme>()!.underlineColor,
                              width: 1.0,
                            ),
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Theme.of(context).extension<NewWalletTheme>()!.underlineColor,
                              width: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                key: ValueKey('unlock'),
                padding: EdgeInsets.only(bottom: 24),
                child: Observer(
                  builder: (_) => LoadingPrimaryButton(
                      onPressed: () async {
                        if (widget.authPasswordHandler != null) {
                          try {
                            await widget
                                .authPasswordHandler!(widget.walletUnlockViewModel.password);
                            widget.walletUnlockViewModel.success();
                          } catch (e) {
                            widget.walletUnlockViewModel.failure(e);
                          }
                          return;
                        }

                        widget.walletUnlockViewModel.unlock();
                      },
                      text: S.of(context).unlock,
                      color: Colors.green,
                      textColor: Colors.white,
                      isLoading: widget.walletUnlockViewModel.state is IsExecutingState,
                      isDisabled: widget.walletUnlockViewModel.state is IsExecutingState),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
