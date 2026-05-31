import 'dart:async';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:frontend/features/conversation/domain/entities/conversation_entity.dart';
import 'package:frontend/features/conversation/domain/usecases/connect_conversation_usecase.dart';
import 'package:frontend/features/conversation/domain/usecases/end_session_usecase.dart';
import 'package:frontend/features/conversation/domain/usecases/send_audio_chunk_usecase.dart';
import 'package:frontend/features/conversation/domain/usecases/start_session_usecase.dart';
import 'package:frontend/features/conversation/domain/usecases/switch_speaker_usecase.dart';

import '../../helpers/test_mocks.mocks.dart';

void main() {
  late MockConversationRepository mockRepository;
  
  late ConnectConversationUseCase connectUseCase;
  late StartSessionUseCase startSessionUseCase;
  late SendAudioChunkUseCase sendAudioChunkUseCase;
  late EndSessionUseCase endSessionUseCase;
  late SwitchSpeakerUseCase switchSpeakerUseCase;

  setUp(() {
    mockRepository = MockConversationRepository();
    
    connectUseCase = ConnectConversationUseCase(mockRepository);
    startSessionUseCase = StartSessionUseCase(mockRepository);
    sendAudioChunkUseCase = SendAudioChunkUseCase(mockRepository);
    endSessionUseCase = EndSessionUseCase(mockRepository);
    switchSpeakerUseCase = SwitchSpeakerUseCase(mockRepository);
  });

  group('Conversation UseCases Tests', () {
    test('ConnectConversationUseCase calls repository.connect', () async {
      final streamController = StreamController<ConversationEvent>();
      when(mockRepository.connect(any)).thenAnswer((_) => streamController.stream);

      final result = connectUseCase(const ConnectConversationParams(accessToken: 'token'));

      expect(result, isA<Right>());
      verify(mockRepository.connect('token')).called(1);
    });

    test('StartSessionUseCase calls repository.startSession', () {
      startSessionUseCase(const StartSessionParams(
        sourceLanguage: 'vi',
        targetLanguage: 'en',
        speaker: ConversationSpeaker.speakerA,
      ));

      verify(mockRepository.startSession(
        sourceLanguage: 'vi',
        targetLanguage: 'en',
        speaker: ConversationSpeaker.speakerA,
      )).called(1);
    });

    test('SendAudioChunkUseCase calls repository.sendAudioChunk', () {
      final chunk = Uint8List.fromList([1, 2, 3]);
      when(mockRepository.connectionStatus).thenReturn(WebSocketConnectionStatus.connected);

      final result = sendAudioChunkUseCase(chunk);

      expect(result, true);
      verify(mockRepository.sendAudioChunk(chunk)).called(1);
    });

    test('EndSessionUseCase calls repository.endSession', () {
      endSessionUseCase();

      verify(mockRepository.endSession()).called(1);
    });

    test('SwitchSpeakerUseCase calls repository.changeSpeaker', () {
      switchSpeakerUseCase(ConversationSpeaker.speakerB);

      verify(mockRepository.changeSpeaker(ConversationSpeaker.speakerB)).called(1);
    });
  });
}
