import 'dart:async';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:frontend/features/conversation/domain/entities/conversation_entity.dart';
import 'package:frontend/features/conversation/presentation/bloc/conversation_viewmodel.dart';

import '../../helpers/test_mocks.mocks.dart';

void main() {
  late ConversationViewModel viewModel;
  late MockConnectConversationUseCase mockConnectUseCase;
  late MockStartSessionUseCase mockStartSessionUseCase;
  late MockSendAudioChunkUseCase mockSendAudioChunkUseCase;
  late MockSwitchSpeakerUseCase mockSwitchSpeakerUseCase;
  late MockEndSessionUseCase mockEndSessionUseCase;
  late MockConversationRepository mockRepository;
  late MockAuthLocalDataSource mockAuthLocalDataSource;
  late MockAudioRecorderService mockAudioRecorderService;

  setUp(() {
    mockConnectUseCase = MockConnectConversationUseCase();
    mockStartSessionUseCase = MockStartSessionUseCase();
    mockSendAudioChunkUseCase = MockSendAudioChunkUseCase();
    mockSwitchSpeakerUseCase = MockSwitchSpeakerUseCase();
    mockEndSessionUseCase = MockEndSessionUseCase();
    mockRepository = MockConversationRepository();
    mockAuthLocalDataSource = MockAuthLocalDataSource();
    mockAudioRecorderService = MockAudioRecorderService();

    viewModel = ConversationViewModel(
      connectUseCase: mockConnectUseCase,
      startSessionUseCase: mockStartSessionUseCase,
      sendAudioChunkUseCase: mockSendAudioChunkUseCase,
      switchSpeakerUseCase: mockSwitchSpeakerUseCase,
      endSessionUseCase: mockEndSessionUseCase,
      repository: mockRepository,
      authLocalDataSource: mockAuthLocalDataSource,
      audioRecorderService: mockAudioRecorderService,
    );
  });

  tearDown(() {
    viewModel.close();
  });

  group('ConversationViewModel Tests', () {
    const tToken = 'test_token';

    test('initial state should be ConversationInitial', () {
      expect(viewModel.state, const ConversationInitial());
    });

    blocTest<ConversationViewModel, ConversationState>(
      'emits [ConversationConnecting, ConversationFailure] when connect fails due to no token',
      build: () {
        when(mockAuthLocalDataSource.getAccessToken()).thenAnswer((_) async => null);
        return viewModel;
      },
      act: (cubit) => cubit.connect(),
      expect: () => [
        isA<ConversationConnecting>(),
        isA<ConversationFailure>().having(
          (s) => s.errorType,
          'errorType',
          ConversationErrorType.authRequired,
        ),
      ],
    );

    blocTest<ConversationViewModel, ConversationState>(
      'emits [ConversationConnecting, ConversationConnected] when connect is successful',
      build: () {
        when(mockAuthLocalDataSource.getAccessToken()).thenAnswer((_) async => tToken);
        final streamController = StreamController<ConversationEvent>();
        when(mockConnectUseCase(any)).thenAnswer((_) => Right(streamController.stream));
        return viewModel;
      },
      act: (cubit) => cubit.connect(),
      expect: () => [
        isA<ConversationConnecting>(),
        isA<ConversationConnected>().having(
          (s) => s.connectionStatus,
          'connectionStatus',
          WebSocketConnectionStatus.connected,
        ),
      ],
    );

    blocTest<ConversationViewModel, ConversationState>(
      'emits [ConversationFailure] when startListening fails due to no mic permission',
      build: () {
        when(mockAudioRecorderService.hasPermission()).thenAnswer((_) async => false);
        return viewModel;
      },
      act: (cubit) => cubit.startListening(),
      expect: () => [
        isA<ConversationFailure>().having(
          (s) => s.errorType,
          'errorType',
          ConversationErrorType.micPermissionDenied,
        ),
      ],
    );

    blocTest<ConversationViewModel, ConversationState>(
      'emits [ConversationRecording] when startListening is successful',
      build: () {
        when(mockAudioRecorderService.hasPermission()).thenAnswer((_) async => true);
        final streamController = StreamController<Uint8List>();
        when(mockAudioRecorderService.startStreamRecording()).thenAnswer((_) async => streamController.stream);
        return viewModel;
      },
      act: (cubit) => cubit.startListening(),
      expect: () => [
        isA<ConversationRecording>(),
      ],
    );

    blocTest<ConversationViewModel, ConversationState>(
      'stopListening emits [ConversationProcessing] and calls endUtterance',
      build: () {
        when(mockAudioRecorderService.isRecording).thenReturn(true);
        when(mockAudioRecorderService.stopStreamRecording()).thenAnswer((_) async {});
        return viewModel;
      },
      act: (cubit) => cubit.stopListening(),
      verify: (_) {
        verify(mockRepository.endUtterance()).called(1);
      },
      expect: () => [
        isA<ConversationProcessing>(),
      ],
    );
  });
}
