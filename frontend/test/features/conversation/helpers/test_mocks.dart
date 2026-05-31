import 'package:mockito/annotations.dart';
import 'package:frontend/features/conversation/domain/repositories/conversation_repository.dart';
import 'package:frontend/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:frontend/core/audio_recorder/audio_recorder_service.dart';
import 'package:frontend/features/conversation/domain/usecases/connect_conversation_usecase.dart';
import 'package:frontend/features/conversation/domain/usecases/start_session_usecase.dart';
import 'package:frontend/features/conversation/domain/usecases/send_audio_chunk_usecase.dart';
import 'package:frontend/features/conversation/domain/usecases/switch_speaker_usecase.dart';
import 'package:frontend/features/conversation/domain/usecases/end_session_usecase.dart';

@GenerateNiceMocks([
  MockSpec<ConversationRepository>(),
  MockSpec<AuthLocalDataSource>(),
  MockSpec<AudioRecorderService>(),
  MockSpec<ConnectConversationUseCase>(),
  MockSpec<StartSessionUseCase>(),
  MockSpec<SendAudioChunkUseCase>(),
  MockSpec<SwitchSpeakerUseCase>(),
  MockSpec<EndSessionUseCase>(),
])
void main() {}
