import 'package:dartz/dartz.dart';
import 'package:frontend/core/error/failures.dart';
import 'package:frontend/core/usecases/usecase.dart';
import 'package:frontend/features/auth/domain/repositories/auth_repository.dart';

class CheckEmailUseCase implements UseCase<bool, String> {
  final AuthRepository repository;

  CheckEmailUseCase(this.repository);

  @override
  Future<Either<Failure, bool>> call(String email) async {
    return await repository.checkEmail(email);
  }
}
