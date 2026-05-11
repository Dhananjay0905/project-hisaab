/// TransactionRepositoryImpl — bridges transaction data layer with domain.
library;

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/transaction.dart';
import '../datasources/transaction_remote_datasource.dart';

class TransactionRepositoryImpl {
  const TransactionRepositoryImpl(this._remote);
  final TransactionRemoteDataSource _remote;

  Future<TransactionPage> getTransactions({
    int page = 1,
    int limit = 20,
    String? type,
    List<String> categoryIds = const [],
    String? startDate,
    String? endDate,
    String? search,
    String sortBy = 'date',
    String sortOrder = 'desc',
  }) async {
    try {
      final model = await _remote.getTransactions(
        page: page,
        limit: limit,
        type: type,
        categoryIds: categoryIds,
        startDate: startDate,
        endDate: endDate,
        search: search,
        sortBy: sortBy,
        sortOrder: sortOrder,
      );
      return TransactionPage(
        items: model.items,
        total: model.total,
        page: model.page,
        limit: model.limit,
        pages: model.pages,
        hasNext: model.hasNext,
        hasPrev: model.hasPrev,
      );
    } on NetworkException {
      throw const NetworkFailure();
    } on AppException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  Future<Transaction> getTransaction(String id) async {
    try {
      return await _remote.getTransaction(id);
    } on NotFoundException {
      throw const NotFoundFailure();
    } on NetworkException {
      throw const NetworkFailure();
    } on AppException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  Future<Transaction> createTransaction({
    required String title,
    required double amount,
    required String type,
    required DateTime date,
    String? note,
    String? categoryId,
    bool excludeFromAnalytics = false,
  }) async {
    try {
      return await _remote.createTransaction(
        title: title,
        amount: amount,
        type: type,
        date: date,
        note: note,
        categoryId: categoryId,
        excludeFromAnalytics: excludeFromAnalytics,
      );
    } on ValidationException catch (e) {
      throw ValidationFailure(e.message, fieldErrors: e.fieldErrors);
    } on NetworkException {
      throw const NetworkFailure();
    } on AppException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  Future<Transaction> updateTransaction(
    String id, {
    String? title,
    double? amount,
    String? type,
    DateTime? date,
    String? note,
    String? categoryId,
    bool? excludeFromAnalytics,
  }) async {
    try {
      return await _remote.updateTransaction(
        id,
        title: title,
        amount: amount,
        type: type,
        date: date,
        note: note,
        categoryId: categoryId,
        excludeFromAnalytics: excludeFromAnalytics,
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

  Future<void> deleteTransaction(String id) async {
    try {
      await _remote.deleteTransaction(id);
    } on NotFoundException {
      throw const NotFoundFailure();
    } on NetworkException {
      throw const NetworkFailure();
    } on AppException catch (e) {
      throw ServerFailure(e.message);
    }
  }
}
