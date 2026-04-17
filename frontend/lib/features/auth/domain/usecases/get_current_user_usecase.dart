import 'package:dartz/dartz.dart';

import 'package:frontend/core/error/failures.dart';
import 'package:frontend/core/usecases/usecase.dart';
import 'package:frontend/features/auth/domain/entities/user_entity.dart';
import 'package:frontend/features/auth/domain/repositories/auth_repository.dart';

/// UC04 — Get current user use case.
///
/// Checks if a valid session exists by reading stored tokens
/// from flutter_secure_storage. If the access token is expired,
/// attempts a silent refresh. Returns the user entity on success
/// or a failure requiring re-login.
class GetCurrentUserUseCase extends UseCase<UserEntity, NoParams> {
  final AuthRepository repository;

  GetCurrentUserUseCase(this.repository);

  @override
  Future<Either<Failure, UserEntity>> call(NoParams params) async {
    return await repository.getCurrentUser();
  }
}
