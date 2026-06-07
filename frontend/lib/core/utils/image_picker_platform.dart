library image_picker_platform;

export 'image_picker_impl_web.dart'
    if (dart.library.io) 'image_picker_impl_mobile.dart';
