/// CategoryRepositoryImpl — bridges categories data layer with domain contract.
/// Translates [AppException] → [Failure].
library;

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/category.dart';
import '../../domain/repositories/category_repository.dart';
import '../datasources/category_remote_datasource.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  const CategoryRepositoryImpl(this._remote);
  final CategoryRemoteDataSource _remote;

  @override
  Future<List<Category>> getCategories() async {
    try {
      return await _remote.getCategories();
    } on NetworkException {
      throw const NetworkFailure();
    } on AppException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<Category> createCategory({
    required String name,
    required String emoji,
    required String type,
    double? monthlyLimit,
  }) async {
    try {
      return await _remote.createCategory(
        name: name,
        emoji: emoji,
        type: type,
        monthlyLimit: monthlyLimit,
      );
    } on ValidationException catch (e) {
      throw ValidationFailure(e.message, fieldErrors: e.fieldErrors);
    } on NetworkException {
      throw const NetworkFailure();
    } on AppException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<Category> updateCategory(
    String id, {
    String? name,
    String? emoji,
    Object? monthlyLimit,
  }) async {
    try {
      return await _remote.updateCategory(
        id,
        name: name,
        emoji: emoji,
        monthlyLimit: monthlyLimit,
      );
    } on ValidationException catch (e) {
      throw ValidationFailure(e.message, fieldErrors: e.fieldErrors);
    } on NotFoundException {
      throw const NotFoundFailure();
    } on NetworkException {
      throw const NetworkFailure();
    } on AppException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> deleteCategory(String id) async {
    try {
      await _remote.deleteCategory(id);
    } on NotFoundException {
      throw const NotFoundFailure();
    } on NetworkException {
      throw const NetworkFailure();
    } on AppException catch (e) {
      throw ServerFailure(e.message);
    }
  }
}
