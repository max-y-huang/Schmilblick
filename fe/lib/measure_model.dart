import 'package:flutter/foundation.dart';

class MeasureModel with ChangeNotifier {
  int _measure = -1;
  set measure(int curMeasure) {
    _measure = curMeasure;
    notifyListeners();
  }

  int get measure => _measure;
}
