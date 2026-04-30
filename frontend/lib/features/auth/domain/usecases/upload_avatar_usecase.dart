import 'package:dartz/dartz.dart';
import 'package:frontend/core/error/failures.dart';
import 'package:frontend/core/usecases/usecase.dart';
import 'package:frontend/features/auth/domain/entities/user_entity.dart';
import 'package:frontend/features/auth/domain/repositories/auth_repository.dart';

class UploadAvatarParams {
  final String filePath;

  UploadAvatarParams({required this.filePath});
}

class UploadAvatarUseCase implements UseCase<UserEntity, UploadAvatarParams> {
  final AuthRepository repository;

  UploadAvatarUseCase(this.repository);

  @override
  Future<Either<Failure, UserEntity>> call(UploadAvatarParams params) async {
    return await repository.uploadAvatar(filePath: params.filePath);
  }
}
