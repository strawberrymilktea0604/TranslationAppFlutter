import 'package:flutter/material.dart';
// TODO: Uncomment when MultiBlocProvider is wired up.
// import 'package:flutter_bloc/flutter_bloc.dart';
import 'app_config.dart';

late AppConfig config;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TODO: Initialize dependencies after packages are added.
  // await initDependencies();

  // TODO: Initialize BlocObserver for global state observation.
  // Bloc.observer = AppBlocObserver();

  runApp(const MyApp());
}

/// Root widget of the application.
/// Global ReadCubits are provided here at the app level.
/// WriteCubits are scoped per-feature at their respective pages.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: Wrap with MultiBlocProvider for global ReadCubits
    // once dependencies are registered.
    //
    // return MultiBlocProvider(
    //   providers: [
    //     BlocProvider(create: (_) => sl<AuthCubit>()),
    //   ],
    //   child: MaterialApp(
    //     title: config.appName,
    //     // TODO: Add GoRouter configuration
    //     home: ...,
    //   ),
    // );

    return MaterialApp(
      title: config.appName,
      home: Scaffold(
        body: Center(
          child: Text("API: ${config.apiUrl}"),
        ),
      ),
    );
  }
}