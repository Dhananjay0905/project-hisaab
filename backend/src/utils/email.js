/**
 * Brevo (formerly Sendinblue) transactional email utility.
 *
 * Uses sib-api-v3-sdk for sending:
 *  - Email verification
 *  - Password reset
 *  - Due date reminders (Phase 3)
 */

const SibApiV3Sdk = require('sib-api-v3-sdk');

// Lazily initialised client
let _client = null;

function getClient() {
  if (_client) return _client;
  const apiKey = process.env.BREVO_API_KEY;
  if (!apiKey) throw new Error('BREVO_API_KEY environment variable is not set.');
  const defaultClient = SibApiV3Sdk.ApiClient.instance;
  defaultClient.authentications['api-key'].apiKey = apiKey;
  _client = new SibApiV3Sdk.TransactionalEmailsApi();
  return _client;
}

const SENDER = {
  email: process.env.BREVO_SENDER_EMAIL || 'noreply@hisaab.app',
  name: process.env.BREVO_SENDER_NAME || 'Hisaab',
};

const APP_URL = process.env.APP_URL || 'http://localhost:3000';
const CLIENT_URL = process.env.CLIENT_URL || 'http://localhost:50013';
const DEEP_LINK = process.env.CLIENT_DEEP_LINK || 'hisaab://';

// ─── Email templates ──────────────────────────────────────────────────────────

/**
 * Sends an email verification link.
 * @param {{ name: string, email: string, token: string }} opts
 */
async function sendVerificationEmail({ name, email, token }) {
  const verifyUrl = `${APP_URL}/api/auth/verify-email?token=${token}`;

  const sendSmtpEmail = new SibApiV3Sdk.SendSmtpEmail();
  sendSmtpEmail.sender = SENDER;
  sendSmtpEmail.to = [{ email, name }];
  sendSmtpEmail.subject = 'Verify your Hisaab account';
  sendSmtpEmail.htmlContent = _verificationTemplate({ name, url: verifyUrl });

  return getClient().sendTransacEmail(sendSmtpEmail);
}

/**
 * Sends a password reset email.
 * @param {{ name: string, email: string, token: string }} opts
 */
async function sendPasswordResetEmail({ name, email, token }) {
  // Deep link lets the mobile app intercept and open the reset screen
  // Falls back to the Flutter web app URL in browser
  const resetUrl = `${CLIENT_URL}/#/reset-password?token=${token}`;

  const sendSmtpEmail = new SibApiV3Sdk.SendSmtpEmail();
  sendSmtpEmail.sender = SENDER;
  sendSmtpEmail.to = [{ email, name }];
  sendSmtpEmail.subject = 'Reset your Hisaab password';
  sendSmtpEmail.htmlContent = _resetTemplate({ name, url: resetUrl });

  return getClient().sendTransacEmail(sendSmtpEmail);
}

/**
 * Sends a confirmation request to the user's CURRENT email.
 * They must click this link to proceed with the email change.
 * @param {{ name: string, email: string, token: string }} opts
 */
async function sendEmailChangeConfirmation({ name, email, token }) {
  const confirmUrl = `${APP_URL}/api/auth/confirm-email-change?token=${token}`;

  const sendSmtpEmail = new SibApiV3Sdk.SendSmtpEmail();
  sendSmtpEmail.sender = SENDER;
  sendSmtpEmail.to = [{ email, name }];
  sendSmtpEmail.subject = 'Confirm your email change request';
  sendSmtpEmail.htmlContent = _emailChangeConfirmTemplate({ name, url: confirmUrl });

  return getClient().sendTransacEmail(sendSmtpEmail);
}

/**
 * Sends verification link to the user's NEW email address.
 * @param {{ name: string, email: string, token: string }} opts
 */
async function sendNewEmailVerification({ name, email, token }) {
  const verifyUrl = `${APP_URL}/api/auth/verify-new-email?token=${token}`;

  const sendSmtpEmail = new SibApiV3Sdk.SendSmtpEmail();
  sendSmtpEmail.sender = SENDER;
  sendSmtpEmail.to = [{ email, name }];
  sendSmtpEmail.subject = 'Verify your new email address';
  sendSmtpEmail.htmlContent = _newEmailVerifyTemplate({ name, url: verifyUrl });

  return getClient().sendTransacEmail(sendSmtpEmail);
}

/**
 * Sends a due date reminder email.
 * @param {{ name: string, email: string, dueTitle: string, amount: string, dueDate: string }} opts
 */
async function sendDueReminderEmail({ name, email, dueTitle, amount, dueDate }) {
  const sendSmtpEmail = new SibApiV3Sdk.SendSmtpEmail();
  sendSmtpEmail.sender = SENDER;
  sendSmtpEmail.to = [{ email, name }];
  sendSmtpEmail.subject = `Reminder: "${dueTitle}" is due soon`;
  sendSmtpEmail.htmlContent = _dueReminderTemplate({ name, dueTitle, amount, dueDate });

  return getClient().sendTransacEmail(sendSmtpEmail);
}

/**
 * Sends an account deletion scheduled email with grace period info.
 * @param {{ name: string, email: string, deleteAt: Date }} opts
 */
async function sendAccountDeletionEmail({ name, email, deleteAt }) {
  const deleteDate = deleteAt.toLocaleDateString('en-IN', {
    day: 'numeric', month: 'long', year: 'numeric',
  });

  const sendSmtpEmail = new SibApiV3Sdk.SendSmtpEmail();
  sendSmtpEmail.sender = SENDER;
  sendSmtpEmail.to = [{ email, name }];
  sendSmtpEmail.subject = 'Your Hisaab account is scheduled for deletion';
  sendSmtpEmail.htmlContent = _accountDeletionTemplate({ name, deleteDate });

  return getClient().sendTransacEmail(sendSmtpEmail);
}

// ─── HTML templates ───────────────────────────────────────────────────────────

function _baseTemplate(content) {
  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Hisaab</title>
</head>
<body style="margin:0;padding:0;background:#F5F6FB;font-family:'Segoe UI',Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#F5F6FB;padding:40px 0;">
    <tr><td align="center">
      <table width="560" cellpadding="0" cellspacing="0" style="background:#FFFFFF;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(56,97,251,0.08);">
        <!-- Header -->
        <tr>
          <td style="background:linear-gradient(135deg,#3861FB,#849AFF);padding:32px 40px;text-align:center;">
            <p style="margin:0;font-size:28px;font-weight:800;color:#fff;letter-spacing:-0.5px;">💳 Hisaab</p>
            <p style="margin:4px 0 0;font-size:13px;color:rgba(255,255,255,0.8);">Your personal finance companion</p>
          </td>
        </tr>
        <!-- Content -->
        <tr><td style="padding:40px;">
          ${content}
        </td></tr>
        <!-- Footer -->
        <tr>
          <td style="padding:20px 40px;background:#F5F6FB;text-align:center;border-top:1px solid #E6E8EE;">
            <p style="margin:0;font-size:12px;color:#595C60;">
              © 2025 Hisaab. This email was sent to you because you have an account with us.<br/>
              If you did not request this, you can safely ignore this email.
            </p>
          </td>
        </tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;
}

function _verificationTemplate({ name, url }) {
  return _baseTemplate(`
    <h2 style="margin:0 0 8px;font-size:22px;color:#2C2F33;font-weight:700;">Welcome, ${name}! 🎉</h2>
    <p style="margin:0 0 24px;font-size:15px;color:#595C60;line-height:1.6;">
      You're almost ready to start tracking your finances. Please verify your email address to activate your account.
    </p>
    <div style="text-align:center;margin-bottom:32px;">
      <a href="${url}" style="display:inline-block;background:linear-gradient(135deg,#3861FB,#849AFF);color:#fff;text-decoration:none;padding:14px 40px;border-radius:12px;font-weight:600;font-size:15px;">
        Verify Email Address
      </a>
    </div>
    <p style="margin:0;font-size:13px;color:#ABABB2;">
      This link expires in <strong>24 hours</strong>. If the button doesn't work, copy this link:<br/>
      <a href="${url}" style="color:#3861FB;word-break:break-all;">${url}</a>
    </p>
  `);
}

function _resetTemplate({ name, url }) {
  return _baseTemplate(`
    <h2 style="margin:0 0 8px;font-size:22px;color:#2C2F33;font-weight:700;">Reset your password 🔑</h2>
    <p style="margin:0 0 24px;font-size:15px;color:#595C60;line-height:1.6;">
      Hi ${name}, we received a request to reset the password for your Hisaab account. 
      Click the button below to choose a new password.
    </p>
    <div style="text-align:center;margin-bottom:32px;">
      <a href="${url}" style="display:inline-block;background:linear-gradient(135deg,#3861FB,#849AFF);color:#fff;text-decoration:none;padding:14px 40px;border-radius:12px;font-weight:600;font-size:15px;">
        Reset Password
      </a>
    </div>
    <p style="margin:0;font-size:13px;color:#ABABB2;">
      This link expires in <strong>1 hour</strong>. If you didn't request a password reset, you can safely ignore this email.<br/><br/>
      If the button doesn't work, copy this link:<br/>
      <a href="${url}" style="color:#3861FB;word-break:break-all;">${url}</a>
    </p>
  `);
}

function _dueReminderTemplate({ name, dueTitle, amount, dueDate }) {
  return _baseTemplate(`
    <h2 style="margin:0 0 8px;font-size:22px;color:#2C2F33;font-weight:700;">Payment reminder ⏰</h2>
    <p style="margin:0 0 24px;font-size:15px;color:#595C60;line-height:1.6;">
      Hi ${name}, this is a friendly reminder about an upcoming due:
    </p>
    <div style="background:#F5F6FB;border-radius:12px;padding:20px;margin-bottom:24px;">
      <p style="margin:0;font-size:18px;font-weight:700;color:#2C2F33;">${dueTitle}</p>
      <p style="margin:4px 0 0;font-size:24px;font-weight:800;color:#3861FB;">${amount}</p>
      <p style="margin:4px 0 0;font-size:13px;color:#595C60;">Due: ${dueDate}</p>
    </div>
    <p style="margin:0;font-size:13px;color:#ABABB2;">
      Open Hisaab to manage your dues and mark them as paid once settled.
    </p>
  `);
}

function _accountDeletionTemplate({ name, deleteDate }) {
  return _baseTemplate(`
    <div style="text-align:center;margin-bottom:28px;">
      <div style="display:inline-block;background:#FEF2F2;border-radius:50%;width:64px;height:64px;line-height:64px;font-size:32px;">🗑️</div>
    </div>
    <h2 style="margin:0 0 8px;font-size:22px;color:#2C2F33;font-weight:700;">Account deletion scheduled</h2>
    <p style="margin:0 0 20px;font-size:15px;color:#595C60;line-height:1.6;">
      Hi ${name}, your Hisaab account has been scheduled for permanent deletion.
    </p>
    <div style="background:#FEF2F2;border:1px solid #FECACA;border-radius:12px;padding:20px;margin-bottom:24px;">
      <p style="margin:0;font-size:13px;color:#991B1B;font-weight:600;">⚠️ Your account and all data will be permanently deleted on:</p>
      <p style="margin:8px 0 0;font-size:22px;font-weight:800;color:#DC2626;">${deleteDate}</p>
    </div>
    <p style="margin:0 0 24px;font-size:15px;color:#595C60;line-height:1.6;">
      Changed your mind? Simply <strong>log in to Hisaab before that date</strong> and your account will be fully restored — no questions asked.
    </p>
    <p style="margin:0;font-size:13px;color:#ABABB2;">
      If you did not request account deletion, please log in immediately and change your password. Your account is safe until the date above.
    </p>
  `);
}

function _emailChangeConfirmTemplate({ name, url }) {
  return _baseTemplate(`
    <h2 style="margin:0 0 8px;font-size:22px;color:#2C2F33;font-weight:700;">Confirm email change ✉️</h2>
    <p style="margin:0 0 24px;font-size:15px;color:#595C60;line-height:1.6;">
      Hi ${name}, we received a request to change the email address on your Hisaab account.
      Click the button below to confirm this request.
    </p>
    <div style="text-align:center;margin-bottom:32px;">
      <a href="${url}" style="display:inline-block;background:linear-gradient(135deg,#3861FB,#849AFF);color:#fff;text-decoration:none;padding:14px 40px;border-radius:12px;font-weight:600;font-size:15px;">
        Confirm Email Change
      </a>
    </div>
    <p style="margin:0;font-size:13px;color:#ABABB2;">
      This link expires in <strong>1 hour</strong>. If you did not request an email change, please ignore this email — your account is safe.<br/><br/>
      If the button doesn't work, copy this link:<br/>
      <a href="${url}" style="color:#3861FB;word-break:break-all;">${url}</a>
    </p>
  `);
}

function _newEmailVerifyTemplate({ name, url }) {
  return _baseTemplate(`
    <h2 style="margin:0 0 8px;font-size:22px;color:#2C2F33;font-weight:700;">Verify your new email 📬</h2>
    <p style="margin:0 0 24px;font-size:15px;color:#595C60;line-height:1.6;">
      Hi ${name}, you're almost done! Click the button below to verify this email address
      and complete your email change on Hisaab.
    </p>
    <div style="text-align:center;margin-bottom:32px;">
      <a href="${url}" style="display:inline-block;background:linear-gradient(135deg,#3861FB,#849AFF);color:#fff;text-decoration:none;padding:14px 40px;border-radius:12px;font-weight:600;font-size:15px;">
        Verify New Email
      </a>
    </div>
    <p style="margin:0;font-size:13px;color:#ABABB2;">
      This link expires in <strong>1 hour</strong>. If you didn't request this, you can safely ignore this email.<br/><br/>
      If the button doesn't work, copy this link:<br/>
      <a href="${url}" style="color:#3861FB;word-break:break-all;">${url}</a>
    </p>
  `);
}

module.exports = {
  sendVerificationEmail,
  sendPasswordResetEmail,
  sendDueReminderEmail,
  sendEmailChangeConfirmation,
  sendNewEmailVerification,
  sendAccountDeletionEmail,
};
