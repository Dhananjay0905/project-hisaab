/// All API endpoint paths. Base URL is configured in [ApiClient].
library;

abstract final class ApiEndpoints {
  // ─── Auth ──────────────────────────────────────────────────────────────────
  static const String register = '/auth/register';
  static const String verifyEmail = '/auth/verify-email';
  static const String resendVerification = '/auth/resend-verification';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String updateProfile = '/auth/profile';
  static const String requestEmailChange = '/auth/request-email-change';
  static const String changePassword = '/auth/change-password';
  static const String deleteAccount  = '/auth/delete-account';
  static const String acceptPolicy   = '/auth/accept-policy';

  // ─── Current user ─────────────────────────────────────────────────────────
  static const String me = '/auth/me';
  static const String meCurrency = '/auth/me/currency';
  static const String meBudget = '/auth/me/budget';

  // ─── Transactions ─────────────────────────────────────────────────────────
  static const String transactions = '/transactions';
  static String transactionById(String id) => '/transactions/$id';
  static String transactionUndo(String id) => '/transactions/$id/undo';
  static String transactionPermanent(String id) => '/transactions/$id/permanent';
  static const String transactionCalendar = '/transactions/calendar';
  static const String transactionsByDate = '/transactions/by-date';

  // ─── Summary ──────────────────────────────────────────────────────────────
  static const String summary = '/summary';

  // ─── Categories ───────────────────────────────────────────────────────────
  static const String categories = '/categories';
  static String categoryById(String id) => '/categories/$id';
  static String categoryUndo(String id) => '/categories/$id/undo';
  static String categoryPermanent(String id) => '/categories/$id/permanent';

  // ─── Dues ─────────────────────────────────────────────────────────────────
  static const String dues = '/dues';
  static String dueById(String id) => '/dues/$id';
  static String dueUndo(String id) => '/dues/$id/undo';
  static String duePermanent(String id) => '/dues/$id/permanent';
  static String dueSettle(String id) => '/dues/$id/settle';

  // ─── Splits ───────────────────────────────────────────────────────────────
  static const String splits = '/splits';
  static String splitById(String id) => '/splits/$id';
  static String splitParticipantPay(String splitId, String pid) =>
      '/splits/$splitId/participants/$pid/pay';
  static String splitParticipantUnpay(String splitId, String pid) =>
      '/splits/$splitId/participants/$pid/unpay';

  // ─── To Receive ───────────────────────────────────────────────────────────
  static const String toReceive = '/to-receive';
  static String toReceiveById(String id) => '/to-receive/$id';
  static String toReceiveUndo(String id) => '/to-receive/$id/undo';
  static String toReceivePermanent(String id) => '/to-receive/$id/permanent';
  static String toReceiveMarkReceived(String id) => '/to-receive/$id/receive';

  // ─── Savings ──────────────────────────────────────────────────────────────
  static const String savings = '/savings';

  // ─── Wishlist ─────────────────────────────────────────────────────────────
  static const String wishlist = '/wishlist';
  static String wishlistById(String id) => '/wishlist/$id';
  static String wishlistToggleDeduct(String id) => '/wishlist/$id/deduct';
  static String wishlistMarkPurchased(String id) => '/wishlist/$id/purchase';

  // ─── Recurring ────────────────────────────────────────────────────────────
  static const String recurring = '/recurring';
  static String recurringById(String id) => '/recurring/$id';
  static String recurringUndo(String id) => '/recurring/$id/undo';
  static String recurringPermanent(String id) => '/recurring/$id/permanent';
  static String recurringCycles(String id) => '/recurring/$id/cycles';
  static String recurringCycleConfirm(String id, String period) =>
      '/recurring/$id/cycles/$period/confirm';

  // ─── Analytics ────────────────────────────────────────────────────────────
  static const String analyticsMonthly    = '/analytics/monthly';
  static const String analyticsCategories = '/analytics/categories';
}
