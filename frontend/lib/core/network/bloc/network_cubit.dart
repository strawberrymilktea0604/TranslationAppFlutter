import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../network_info.dart';

enum NetworkStatus { initial, online, offline }

class NetworkCubit extends Cubit<NetworkStatus> {
  final NetworkInfo networkInfo;
  StreamSubscription<bool>? _networkSubscription;

  NetworkCubit({required this.networkInfo}) : super(NetworkStatus.initial) {
    _init();
  }

  void _init() async {
    // Check initial status
    final isConnected = await networkInfo.isConnected;
    if (!isClosed) {
      emit(isConnected ? NetworkStatus.online : NetworkStatus.offline);
    }

    // Listen to stream for ongoing connectivity changes
    _networkSubscription = networkInfo.onConnectedChange.listen((isConnected) {
      if (!isClosed) {
        emit(isConnected ? NetworkStatus.online : NetworkStatus.offline);
      }
    });
  }

  @override
  Future<void> close() {
    _networkSubscription?.cancel();
    return super.close();
  }
}
