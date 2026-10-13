// Web renders Google's official button; other platforms use our own button.
export 'google_sign_in_button_mobile.dart'
    if (dart.library.js_interop) 'google_sign_in_button_web.dart';
