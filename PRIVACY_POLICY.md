# Privacy Policy

**App:** Hisaab — Personal Finance Tracker  
**Effective Date:** May 17, 2025  
**Last Updated:** May 17, 2025  
**Contact:** hisaab.app@gmail.com

---

## 1. Who We Are

Hisaab ("we", "us", "our") is a personal finance tracking application built and operated as an independent project. Hisaab is **not** a financial institution, bank, or regulated financial service.

---

## 2. What Data We Collect

### 2.1 Account Data
| Field | What We Store | Encrypted? |
|---|---|---|
| **Display name** | Plaintext text | ❌ No |
| **Email address** | Plaintext | ❌ No — required for login, password reset, and transactional emails |
| **Password** | bcrypt hash only | N/A — never stored in any readable form |
| **Currency preference** | Plaintext (e.g. "INR") | ❌ No |
| **Opening balance** | Plaintext decimal | ❌ No |
| **Account creation date** | Timestamp | ❌ No |

### 2.2 Financial Records

The tables below show exactly which fields are encrypted (using AES-256-GCM) and which are not, based on what is implemented in the application code.

#### Transactions
| Field | Encrypted? |
|---|---|
| Title | ✅ Yes — AES-256-GCM |
| Note | ✅ Yes (if provided) — AES-256-GCM |
| Amount | ❌ No — stored as a decimal number |
| Type (income/expense) | ❌ No |
| Date | ❌ No |
| Category reference | ❌ No |

#### Categories
| Field | Encrypted? |
|---|---|
| Name | ❌ No |
| Emoji | ❌ No |
| Type | ❌ No |
| Monthly limit (if set) | ❌ No |

#### Dues (money owed to/from others)
| Field | Encrypted? |
|---|---|
| Title | ✅ Yes — AES-256-GCM |
| Person's name | ✅ Yes — AES-256-GCM |
| Note | ✅ Yes (if provided) — AES-256-GCM |
| Amount | ❌ No — stored as a decimal number |
| Due date | ❌ No |
| Status (paid/unpaid) | ❌ No |

#### Bill Splits
| Field | Encrypted? |
|---|---|
| Split title | ✅ Yes — AES-256-GCM |
| Note | ✅ Yes (if provided) — AES-256-GCM |
| Participant names | ✅ Yes — AES-256-GCM |
| Total amount | ❌ No — stored as a decimal number |
| Per-person amounts | ❌ No — stored as decimal numbers |
| Date | ❌ No |

#### Savings
| Field | Encrypted? |
|---|---|
| Total amount | ❌ No — stored as a decimal number |
| Cash deduction | ❌ No |

> The Savings feature stores a single running total, not a history or title — there is no free-text field to encrypt.

#### Wishlist Items
| Field | Encrypted? |
|---|---|
| Item title | ✅ Yes — AES-256-GCM |
| Emoji | ❌ No |
| Product URL / link | ❌ No |
| Target price | ❌ No — stored as a decimal number |
| Amount saved | ❌ No — stored as a decimal number |

#### Recurring Transactions
| Field | Encrypted? |
|---|---|
| Title | ✅ Yes — AES-256-GCM |
| Amount | ❌ No — stored as a decimal number |
| Type | ❌ No |
| Frequency | ❌ No |
| Next due date | ❌ No |

### 2.3 Authentication Tokens
- **Access tokens** (JWT): Short-lived (15 minutes), stored in device secure storage
- **Refresh tokens**: Long-lived (30 days), stored in device secure storage and the database (as hashed records)
- Both tokens are invalidated on logout and on account deletion

### 2.4 Technical Data (Automatically Collected)
- **Server logs and Security metrics**: IP address, request path, HTTP method, timestamp. Logs are not linked to your identity and are retained for **30 days** for security monitoring. Additionally, your IP address is temporarily tracked in-memory to enforce **rate limits** and **brute-force protection**, ensuring the stability and security of the platform.
- We do **not** collect: device fingerprints, advertising IDs, crash reports, analytics events, or behavioural tracking data.

---

## 3. What Is and Is Not Encrypted

### ✅ Encrypted with AES-256-GCM
The following free-text fields that could identify real people or reveal personal details are encrypted before being written to the database:

- Transaction **titles** and **notes**
- Due **titles**, **person names**, and **notes**
- Split **titles**, **notes**, and **participant names**
- Wishlist item **titles**
- Recurring transaction **titles**

### ❌ Not Encrypted (stored as plaintext)
- **Your display name and email address** — required for authentication and communication
- **All numeric amounts** (transaction amounts, due amounts, savings totals, prices) — stored as decimal numbers; these cannot be encrypted while still supporting server-side aggregation for your summaries and analytics
- **Category names and emojis** — used as labels/filters; no personal text
- **Dates and timestamps**
- **Boolean and enum flags** (e.g. paid/unpaid, income/expense, frequency)
- **Wishlist product URLs** — not considered personally identifiable information
- **Savings pot amounts** — single running totals

### 🔒 Passwords
Passwords are **never** stored. They are hashed with bcrypt (cost factor 12) and only the hash is saved. We cannot recover your password.

### ⚠️ Operator access (important)
Hisaab uses **server-side encryption**, not end-to-end encryption. This means the encryption key lives on the server alongside the application. While we do not access or read your data, the server operator (i.e., us) is technically capable of decrypting the encrypted fields. We commit not to access user data except for essential operational tasks requested by you (e.g., debugging a critical data issue you report).

Numeric amounts and metadata (dates, types, category names) are stored in plaintext and are directly readable in the database.

---

## 4. How We Use Your Data

| Purpose | Legal Basis (GDPR) |
|---|---|
| Providing the app (storing and displaying your financial records) | Contract performance |
| Account authentication | Contract performance |
| Sending transactional emails (verification, password reset, deletion notice) | Contract performance |
| Security monitoring, rate limiting, and brute-force protection | Legitimate interest |
| Responding to your support requests | Legitimate interest |

We do **not** use your data for advertising, profiling, or sale to third parties. We have **no advertising partners**.

---

## 5. Where Your Data Is Stored

| Service | Purpose | Provider | Region |
|---|---|---|---|
| **Neon** | PostgreSQL database (all app data) | Neon Inc. (on AWS) | **ap-southeast-1 (Singapore)** |
| **Render** | API server hosting | Render Inc. | Oregon, USA (US West) |
| **Brevo** (formerly Sendinblue) | Transactional email delivery | Brevo SAS | European Union (France) |

### Data Transfers
Your data is stored in Singapore (Neon/AWS ap-southeast-1) and processed via servers in the United States (Render). If you are located in the European Economic Area (EEA), this constitutes a transfer to third countries. These transfers are covered by:
- Neon's data processing agreement with AWS, which operates under the EU-U.S. Data Privacy Framework
- Render's data processing agreement
- Brevo's Standard Contractual Clauses (SCCs)

---

## 6. Data Retention

| Data | Retained Until |
|---|---|
| Your account and all financial records | Until you delete your account |
| Deleted account data | Permanently erased after the 5-day deletion grace period expires |
| Server access logs | 30 days, then automatically purged |
| Revoked/expired refresh tokens | Cleaned up automatically on next login |
| Password reset tokens | 1 hour, then expired |
| Email change tokens | 1 hour, then expired |

---

## 7. Account Deletion & Your Right to Erasure

You can delete your account at any time from **More → Delete Account** in the app.

**How it works:**
1. Enter your password to confirm
2. Your account enters a **5-day grace period** — it remains fully accessible
3. You will receive a confirmation email with the scheduled deletion date
4. If you **log in before the deadline**, the deletion is automatically cancelled and your account is fully restored
5. If you **do not log in**, all data (account, transactions, categories, dues, splits, savings goals, wishlist, recurring entries) is **permanently and irreversibly deleted** from the database

There is no backup of your data after deletion. Deletion is cascading — all related records are deleted together.

---

## 8. Cookies & Local Storage

**Hisaab is a mobile application.** We do **not** use browser cookies.

Instead, the app uses **device secure storage** (iOS Keychain / Android Keystore via `flutter_secure_storage`) to store:
- Your JWT access token
- Your JWT refresh token
- Basic session info (user ID, email, name, currency) for offline use

These are stored **only on your device** and are cleared when you log out.

If Hisaab is ever accessed via a web browser, the same tokens may be stored in `localStorage`. No third-party tracking cookies are ever set.

---

## 9. Your Rights Under GDPR (EEA/UK Users)

If you are in the European Economic Area or United Kingdom, you have the following rights:

| Right | How to Exercise |
|---|---|
| **Right to access** | View all your data within the app at any time |
| **Right to rectification** | Edit your name and email in the app (More → Profile) |
| **Right to erasure** | Delete your account (More → Delete Account) |
| **Right to data portability** | Email us at hisaab.app@gmail.com — we will provide a JSON export |
| **Right to object** | Email us to object to any processing |
| **Right to restrict processing** | Email us — we will restrict your data while we address your concern |
| **Right to withdraw consent** | Where processing is consent-based, you may withdraw at any time |

We aim to respond to all rights requests within **30 days**. If you believe we have not handled your data correctly, you have the right to lodge a complaint with your local supervisory authority.

---

## 10. Your Rights Under CCPA (California Residents)

If you are a California resident, you have the right to:

- **Know** what personal information we collect, use, and disclose
- **Delete** your personal information (exercise via More → Delete Account or by emailing us)
- **Correct** inaccurate personal information
- **Opt out of the sale or sharing** of your personal information — **we do not sell or share your data**, so this right is not applicable but is guaranteed
- **Non-discrimination** for exercising your privacy rights

To exercise your rights, contact us at hisaab.app@gmail.com with the subject line "CCPA Request".

---

## 11. Children's Privacy

Hisaab is not directed at children under the age of 13 (or 16 in the EEA). We do not knowingly collect personal data from minors. If you believe a minor has created an account, please contact us and we will delete it promptly.

---

## 12. Security

We take reasonable technical and organisational measures to protect your data:
- AES-256-GCM encryption for sensitive text fields
- bcrypt (cost 12) for password hashing
- JWT-based authentication with short-lived access tokens
- Refresh token rotation and revocation on logout
- HTTPS-only API communication
- Rate limiting on authentication endpoints
- No plaintext passwords ever logged or stored

Despite these measures, no system is perfectly secure. We cannot guarantee absolute security.

---

## 13. Changes to This Policy

We may update this Privacy Policy from time to time. When we do, we will update the "Last Updated" date at the top. For significant changes, we will attempt to notify users via email or an in-app notice.

---

## 14. Contact Us

If you have any questions about this Privacy Policy or how we handle your data:

**Email:** hisaab.app@gmail.com  
**Subject line:** "Privacy Inquiry"

We will respond within 14 business days.

---

*This Privacy Policy is written in plain language intentionally. If any section is unclear, please email us and we will clarify.*
