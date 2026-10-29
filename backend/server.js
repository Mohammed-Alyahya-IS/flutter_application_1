const express = require('express');
const mysql = require('mysql2/promise');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const cors = require('cors');
const {
  normalizeEmail,
  matchesRecipientInvitation,
  isPendingRecipientInvitation,
} = require('./invitation-logic');

const app = express();
app.use(express.json({ limit: '1mb' }));
app.use(cors());

const db = mysql.createPool({
  host: 'localhost',
  user: 'root',
  password: '2005',
  database: 'qitta_db',
  waitForConnections: true,
  connectionLimit: 20,
  charset: 'utf8mb4',
});

const JWT_SECRET = 'qitta_super_secret_key_123';

const buildToken = (user) =>
  jwt.sign({ id: user.id, email: user.email }, JWT_SECRET, { expiresIn: '7d' });

async function cleanupStaleMembershipData() {
  await db.query(`
    DELETE gm
    FROM ` + '`group_members`' + ` gm
    LEFT JOIN users u ON u.id = gm.user_id
    WHERE gm.user_id IS NOT NULL AND u.id IS NULL
  `);

  await db.query(`
    UPDATE ` + '`group_members`' + ` gm
    INNER JOIN users u ON LOWER(TRIM(u.email)) = LOWER(TRIM(gm.email))
    SET gm.user_id = u.id
    WHERE gm.user_id IS NULL
      AND gm.status = 'pending'
      AND LOWER(TRIM(gm.email)) = LOWER(TRIM(u.email))
  `);

  await db.query(`
    DELETE gm
    FROM ` + '`group_members`' + ` gm
    LEFT JOIN users u ON u.id = gm.user_id
    LEFT JOIN users recipient ON LOWER(TRIM(recipient.email)) = LOWER(TRIM(gm.email))
    WHERE gm.user_id IS NOT NULL
      AND (
        u.id IS NULL
        OR (recipient.id IS NOT NULL AND recipient.id <> gm.user_id)
      )
  `);

  await db.query(`
    DELETE FROM ` + '`group_members`' + `
    WHERE TRIM(email) = ''
  `);

  await db.query(`
    DELETE gm1
    FROM ` + '`group_members`' + ` gm1
    INNER JOIN ` + '`group_members`' + ` gm2
      ON gm1.group_id = gm2.group_id
     AND LOWER(TRIM(gm1.email)) = LOWER(TRIM(gm2.email))
     AND gm1.id > gm2.id
    WHERE gm1.status = 'pending' AND gm2.status = 'pending'
  `);
}

async function ensureDatabaseSchema() {
  const rootConnection = await mysql.createConnection({
    host: 'localhost',
    user: 'root',
    password: '2005',
    charset: 'utf8mb4',
  });

  await rootConnection.query('CREATE DATABASE IF NOT EXISTS qitta_db');
  await rootConnection.end();

  await db.query(`
    CREATE TABLE IF NOT EXISTS users (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      name VARCHAR(255) NOT NULL,
      email VARCHAR(255) NOT NULL,
      password_hash VARCHAR(255) NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      UNIQUE KEY unique_user_email (email)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  `);

  await db.query(`
    CREATE TABLE IF NOT EXISTS ` + '`groups`' + ` (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      name VARCHAR(255) NOT NULL,
      owner_user_id BIGINT UNSIGNED NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      CONSTRAINT fk_group_owner FOREIGN KEY (owner_user_id) REFERENCES users(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  `);

  await db.query(`
    CREATE TABLE IF NOT EXISTS ` + '`group_members`' + ` (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      group_id BIGINT UNSIGNED NOT NULL,
      user_id BIGINT UNSIGNED NULL,
      email VARCHAR(255) NOT NULL,
      status ENUM('pending', 'accepted', 'rejected') NOT NULL DEFAULT 'pending',
      role ENUM('owner', 'member') NOT NULL DEFAULT 'member',
      invited_by BIGINT UNSIGNED NULL,
      wallet_balance DECIMAL(12,2) NOT NULL DEFAULT 0.00,
      amount_owed DECIMAL(12,2) NOT NULL DEFAULT 0.00,
      amount_receivable DECIMAL(12,2) NOT NULL DEFAULT 0.00,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      UNIQUE KEY unique_group_member_user (group_id, user_id),
      UNIQUE KEY unique_group_member_email (group_id, email),
      KEY idx_group_members_email (email),
      KEY idx_group_members_status (status),
      CONSTRAINT fk_group_member_group FOREIGN KEY (group_id) REFERENCES ` + '`groups`' + `(id) ON DELETE CASCADE,
      CONSTRAINT fk_group_member_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
      CONSTRAINT fk_group_member_inviter FOREIGN KEY (invited_by) REFERENCES users(id) ON DELETE SET NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  `);

  for (const [column, definition] of [
    ['wallet_balance', 'DECIMAL(12,2) NOT NULL DEFAULT 0.00'],
    ['amount_owed', 'DECIMAL(12,2) NOT NULL DEFAULT 0.00'],
    ['amount_receivable', 'DECIMAL(12,2) NOT NULL DEFAULT 0.00'],
  ]) {
    const [columns] = await db.query(
      'SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?',
      ['group_members', column],
    );
    if (columns.length === 0) {
      await db.query(`ALTER TABLE \`group_members\` ADD COLUMN \`${column}\` ${definition}`);
    }
  }

  await db.query(`
    CREATE TABLE IF NOT EXISTS ` + '`expenses`' + ` (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      group_id BIGINT UNSIGNED NOT NULL,
      title VARCHAR(255) NOT NULL,
      amount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
      payer_user_id BIGINT UNSIGNED NOT NULL,
      payer_email VARCHAR(255) NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      KEY idx_expenses_group (group_id),
      CONSTRAINT fk_expense_group FOREIGN KEY (group_id) REFERENCES ` + '`groups`' + `(id) ON DELETE CASCADE,
      CONSTRAINT fk_expense_payer FOREIGN KEY (payer_user_id) REFERENCES users(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  `);

  await db.query(`
    CREATE TABLE IF NOT EXISTS wallet_debts (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      expense_id BIGINT UNSIGNED NOT NULL,
      debtor_member_id BIGINT UNSIGNED NOT NULL,
      creditor_member_id BIGINT UNSIGNED NOT NULL,
      outstanding_amount DECIMAL(12,2) NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      KEY idx_wallet_debts_debtor (debtor_member_id, outstanding_amount, created_at),
      CONSTRAINT fk_wallet_debt_expense FOREIGN KEY (expense_id) REFERENCES ` + '`expenses`' + `(id) ON DELETE CASCADE,
      CONSTRAINT fk_wallet_debt_debtor FOREIGN KEY (debtor_member_id) REFERENCES ` + '`group_members`' + `(id) ON DELETE CASCADE,
      CONSTRAINT fk_wallet_debt_creditor FOREIGN KEY (creditor_member_id) REFERENCES ` + '`group_members`' + `(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  `);

  await cleanupStaleMembershipData();

  console.log('Database schema verified and initialized for user-isolated groups and invitations.');
}

function getAuthUser(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;

  if (!token) {
    return res.status(401).json({ error: 'Authorization token is required' });
  }

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded;
    return next();
  } catch (error) {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

const getUserByEmail = async (email) => {
  const normalizedEmail = normalizeEmail(email);
  const [rows] = await db.query('SELECT * FROM users WHERE email = ?', [normalizedEmail]);
  return rows[0] || null;
};

const getUserById = async (id) => {
  const [rows] = await db.query('SELECT * FROM users WHERE id = ?', [id]);
  return rows[0] || null;
};

const getGroupById = async (groupId) => {
  const [rows] = await db.query('SELECT * FROM `groups` WHERE id = ?', [groupId]);
  return rows[0] || null;
};

const getUserInvitationRows = async (userId, email) => {
  const normalizedEmail = normalizeEmail(email);
  const [rows] = await db.query(
    `
      SELECT gm.id, gm.group_id, g.name AS group_name, gm.email, gm.user_id, gm.status, gm.created_at
      FROM ` + '`group_members`' + ` gm
      INNER JOIN ` + '`groups`' + ` g ON g.id = gm.group_id
      WHERE gm.status = 'pending'
        AND (
          (gm.user_id = ? AND LOWER(TRIM(gm.email)) = ?)
          OR (gm.user_id IS NULL AND LOWER(TRIM(gm.email)) = ?)
        )
      ORDER BY gm.created_at DESC
    `,
    [Number(userId), normalizedEmail, normalizedEmail],
  );

  return rows.filter((row) => {
    const rowEmail = normalizeEmail(row.email || '');
    const rowUserId = Number(row.user_id ?? 0);
    return (
      (rowUserId === Number(userId) && rowEmail === normalizedEmail) ||
      (rowUserId === 0 && rowEmail === normalizedEmail)
    );
  });
};

const getAccessibleGroupsForUser = async (userId) => {
  const [groupRows] = await db.query(
    `
      SELECT g.id, g.name, g.owner_user_id, u.email AS owner_email, g.created_at
      FROM \`groups\` g
      INNER JOIN users u ON u.id = g.owner_user_id
      WHERE g.owner_user_id = ?
         OR EXISTS (
           SELECT 1
           FROM \`group_members\` gm
           WHERE gm.group_id = g.id
             AND gm.user_id = ?
             AND gm.status = 'accepted'
         )
      ORDER BY g.created_at DESC
    `,
    [userId, userId],
  );

  const groups = [];

  for (const group of groupRows) {
    const [memberRows] = await db.query(
      `
        SELECT gm.id, gm.user_id, gm.email, gm.role, gm.status,
               gm.wallet_balance, gm.amount_owed, gm.amount_receivable,
               COALESCE(u.name, gm.email) AS member_name
        FROM \`group_members\` gm
        LEFT JOIN users u ON u.id = gm.user_id
        WHERE gm.group_id = ? AND gm.status = 'accepted'
        ORDER BY gm.created_at ASC
      `,
      [group.id],
    );

    groups.push({
      id: Number(group.id),
      name: group.name,
      ownerUserId: Number(group.owner_user_id),
      ownerEmail: normalizeEmail(group.owner_email || ''),
      createdAt: group.created_at,
      members: memberRows.map((member) => ({
        id: Number(member.id),
        userId: Number(member.user_id || 0),
        email: normalizeEmail(member.email || ''),
        name: String(member.member_name || member.email || ''),
        role: member.role,
        status: member.status,
        ...(Number(member.user_id) === Number(userId)
          ? {
              walletBalance: Number(member.wallet_balance || 0),
              amountOwed: Number(member.amount_owed || 0),
              amountReceivable: Number(member.amount_receivable || 0),
            }
          : {}),
      })),
    });
  }

  return groups;
};

const getAccessibleExpensesForUser = async (userId) => {
  const [rows] = await db.query(`
    SELECT e.*
    FROM ` + '`expenses`' + ` e
    INNER JOIN ` + '`group_members`' + ` gm ON gm.group_id = e.group_id
    WHERE gm.user_id = ?
      AND gm.status = 'accepted'
    ORDER BY e.created_at DESC
  `, [userId]);

  return rows;
};

const registerUser = async (req, res) => {
  const { name, email, password } = req.body;
  const normalizedName = String(name || '').trim();
  const normalizedEmail = normalizeEmail(email);

  if (!normalizedName || !normalizedEmail || !password) {
    return res.status(400).json({ error: 'All required fields must be filled' });
  }

  try {
    const existing = await getUserByEmail(normalizedEmail);
    if (existing) {
      return res.status(400).json({ error: 'البريد الإلكتروني مسجل مسبقاً' });
    }

    const hashedPassword = await bcrypt.hash(String(password), 10);
    const [result] = await db.query(
      'INSERT INTO users (name, email, password_hash) VALUES (?, ?, ?)',
      [normalizedName, normalizedEmail, hashedPassword]
    );

    const user = { id: result.insertId, name: normalizedName, email: normalizedEmail };
    const token = buildToken(user);

    return res.status(201).json({
      message: 'تم إنشاء الحساب بنجاح',
      token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        groups: [],
        expenses: [],
      },
    });
  } catch (error) {
    console.error('Register error:', error);
    return res.status(500).json({ error: 'حدث خطأ في السيرفر', details: error.message });
  }
};

const loginUser = async (req, res) => {
  const { email, password } = req.body;
  const normalizedEmail = normalizeEmail(email);

  if (!normalizedEmail || !password) {
    return res.status(400).json({ error: 'البريد وكلمة المرور مطلوبان' });
  }

  try {
    const user = await getUserByEmail(normalizedEmail);
    if (!user) {
      return res.status(400).json({ error: 'بيانات الدخول غير صحيحة' });
    }

    const isPasswordValid = await bcrypt.compare(String(password), user.password_hash);
    if (!isPasswordValid) {
      return res.status(400).json({ error: 'بيانات الدخول غير صحيحة' });
    }

    const token = buildToken(user);
    const groups = await getAccessibleGroupsForUser(user.id);
    const expenses = await getAccessibleExpensesForUser(user.id);

    return res.json({
      message: 'تم تسجيل الدخول بنجاح',
      token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        groups,
        expenses,
      },
    });
  } catch (error) {
    console.error('Login error:', error);
    return res.status(500).json({ error: 'حدث خطأ في السيرفر', details: error.message });
  }
};

app.get('/api/health', (req, res) => {
  res.json({ ok: true, message: 'API is running' });
});

app.post('/api/register', (req, res) => registerUser(req, res));
app.post('/api/auth/register', (req, res) => registerUser(req, res));

app.post('/api/login', (req, res) => loginUser(req, res));
app.post('/api/auth/login', (req, res) => loginUser(req, res));

app.get('/api/me', getAuthUser, async (req, res) => {
  try {
    const user = await getUserById(req.user.id);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const groups = await getAccessibleGroupsForUser(user.id);
    const expenses = await getAccessibleExpensesForUser(user.id);

    return res.json({
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        groups,
        expenses,
      },
    });
  } catch (error) {
    console.error('Get profile error:', error);
    return res.status(500).json({ error: 'Failed to load profile' });
  }
});

app.get('/api/groups', getAuthUser, async (req, res) => {
  try {
    const groups = await getAccessibleGroupsForUser(req.user.id);
    return res.json({ groups });
  } catch (error) {
    console.error('Get groups error:', error);
    return res.status(500).json({ error: 'Failed to load groups' });
  }
});

app.post('/api/groups', getAuthUser, async (req, res) => {
  const { name } = req.body;
  const groupName = name ? name.trim() : '';

  if (!groupName) {
    return res.status(400).json({ error: 'يجب إدخال اسم المجموعة' });
  }

  try {
    // 1. إنشاء المجموعة وتسجيل المنشئ كمدير لها
    const [result] = await db.query(
      'INSERT INTO `groups` (name, owner_user_id) VALUES (?, ?)',
      [groupName, req.user.id]
    );

    const groupId = result.insertId;

    // 2. إضافتك تلقائياً كعضو أساسي بصلاحية owner وحالة accepted
    await db.query(
      'INSERT INTO `group_members` (group_id, user_id, email, status, role, invited_by) VALUES (?, ?, ?, "accepted", "owner", ?)',
      [groupId, req.user.id, req.user.email, req.user.id]
    );

    return res.status(201).json({
      message: 'تم إنشاء المجموعة بنجاح',
      group: { id: groupId, name: groupName, owner_user_id: req.user.id },
    });
  } catch (error) {
    console.error('Create group error:', error);
    return res.status(500).json({ error: 'Failed to create group', details: error.message });
  }
});

app.post('/api/groups/:groupId/invite', getAuthUser, async (req, res) => {
  const { groupId } = req.params;
  const { email } = req.body;
  const inviteEmail = normalizeEmail(email);

  if (!/^[1-9]\d*$/.test(groupId)) {
    return res.status(400).json({ error: 'معرف المجموعة غير صالح' });
  }

  if (!inviteEmail || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(inviteEmail)) {
    return res.status(400).json({ error: 'يجب إدخال البريد الإلكتروني للعضو' });
  }

  try {
    const user = await getUserById(req.user.id);
    const group = await getGroupById(groupId);

    if (!user || !group) {
      return res.status(404).json({ error: 'المجموعة أو المستخدم غير موجودة' });
    }

    if (Number(group.owner_user_id) !== Number(user.id)) {
      return res.status(403).json({ error: 'فقط صاحب المجموعة يمكنه دعوة الأعضاء' });
    }

    if (inviteEmail === normalizeEmail(user.email)) {
      return res.status(400).json({ error: 'لا يمكنك دعوة حسابك الشخصي' });
    }

    const invitedUser = await getUserByEmail(inviteEmail);
    if (!invitedUser) {
      return res.status(404).json({ error: 'لا يوجد حساب بهذا البريد الإلكتروني في النظام' });
    }

    const [existingMember] = await db.query(
      'SELECT * FROM `group_members` WHERE group_id = ? AND user_id = ? AND email = ? ORDER BY created_at DESC LIMIT 1',
      [groupId, invitedUser.id, inviteEmail]
    );

    if (existingMember.length > 0) {
      const membership = existingMember[0];
      if (membership.status === 'accepted') {
        return res.status(409).json({ error: 'هذا العضو موجود بالفعل في المجموعة' });
      }
      if (membership.status === 'pending') {
        return res.status(200).json({
          message: 'الدعوة موجودة بالفعل وبانتظار رد العضو',
          invitation: {
            id: Number(membership.id),
            group_id: Number(groupId),
            group_name: group.name,
            email: inviteEmail,
            status: 'pending',
          },
        });
      }

      await db.query(
        'UPDATE `group_members` SET user_id = ?, email = ?, status = "pending", role = "member", invited_by = ? WHERE id = ?',
        [invitedUser.id, inviteEmail, user.id, membership.id],
      );

      return res.status(200).json({
        message: 'تم تحديث دعوتك لهذا العضو بنجاح',
        invitation: {
          id: membership.id,
          group_id: Number(groupId),
          group_name: group.name,
          email: inviteEmail,
          status: 'pending',
        },
      });
    }

    const [result] = await db.query(
      'INSERT INTO `group_members` (group_id, user_id, email, status, role, invited_by) VALUES (?, ?, ?, "pending", "member", ?)',
      [groupId, invitedUser.id, inviteEmail, user.id]
    );

    return res.status(201).json({
      message: 'تم إرسال دعوة العضو بنجاح',
      invitation: {
        id: result.insertId,
        group_id: Number(groupId),
        group_name: group.name,
        email: inviteEmail,
        status: 'pending',
      },
    });
  } catch (error) {
    console.error('Invite member error:', error);
    return res.status(500).json({ error: 'فشل إرسال الدعوة', details: error.message });
  }
});

app.get('/api/invitations', getAuthUser, async (req, res) => {
  try {
    const rows = await getUserInvitationRows(req.user.id, req.user.email);
    return res.json({ invitations: rows });
  } catch (error) {
    console.error('Get invitations error:', error);
    return res.status(500).json({ error: 'Failed to fetch invitations' });
  }
});

app.post('/api/invitations/:invitationId/respond', getAuthUser, async (req, res) => {
  const { invitationId } = req.params;
  const { status } = req.body;

  if (!/^[1-9]\d*$/.test(invitationId)) {
    return res.status(400).json({ error: 'معرف الدعوة غير صالح' });
  }

  if (!['accepted', 'rejected'].includes(status)) {
    return res.status(400).json({ error: 'الحالة غير صالحة، يجب أن تكون accepted أو rejected' });
  }

  try {
    const [rows] = await db.query(
      'SELECT * FROM `group_members` WHERE id = ? AND ((user_id = ? AND email = ?) OR (user_id IS NULL AND email = ?)) LIMIT 1',
      [invitationId, req.user.id, normalizeEmail(req.user.email), normalizeEmail(req.user.email)]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: 'الدعوة غير موجودة لهذا المستخدم' });
    }

    const invitation = rows[0];
    if (!isPendingRecipientInvitation(invitation, req.user.id, req.user.email)) {
      return res.status(409).json({ error: 'هذه الدعوة تم الرد عليها مسبقاً' });
    }

    const [updateResult] = await db.query(
      'UPDATE `group_members` SET status = ?, user_id = ?, email = ? WHERE id = ? AND status = "pending" AND ((user_id = ? AND email = ?) OR (user_id IS NULL AND email = ?))',
      [status, req.user.id, normalizeEmail(req.user.email), invitationId, req.user.id, normalizeEmail(req.user.email), normalizeEmail(req.user.email)]
    );

    if (updateResult.affectedRows === 0) {
      return res.status(409).json({ error: 'هذه الدعوة تم الرد عليها مسبقاً' });
    }

    if (status === 'accepted') {
      return res.json({ message: 'تم قبول الدعوة بنجاح، وأصبح العضو جزءاً من المجموعة' });
    }

    return res.json({ message: 'تم رفض الدعوة بنجاح' });
  } catch (error) {
    console.error('Respond to invitation error:', error);
    return res.status(500).json({ error: 'Failed to update invitation', details: error.message });
  }
});

app.post('/api/groups/:groupId/wallet/recharge', getAuthUser, async (req, res) => {
  const { groupId } = req.params;
  const amount = Math.round(Number(req.body.amount) * 100) / 100;
  if (!/^[1-9]\d*$/.test(groupId) || !Number.isFinite(amount) || amount < 0.01) {
    return res.status(400).json({ error: 'بيانات شحن الرصيد غير صحيحة' });
  }

  const connection = await db.getConnection();
  try {
    await connection.beginTransaction();
    const [members] = await connection.query(
      'SELECT id, user_id, wallet_balance FROM `group_members` WHERE group_id = ? AND status = "accepted" ORDER BY id FOR UPDATE',
      [groupId],
    );
    const member = members.find(
      (row) => Number(row.user_id) === Number(req.user.id),
    );
    if (!member) {
      await connection.rollback();
      return res.status(403).json({ error: 'لا يمكنك شحن محفظة هذه المجموعة' });
    }

    const [result] = await connection.query(
      'UPDATE `group_members` SET wallet_balance = wallet_balance + ? WHERE id = ?',
      [amount.toFixed(2), member.id],
    );
    if (result.affectedRows !== 1) {
      throw new Error('Wallet balance was not updated');
    }

    let walletBalanceCents =
      Math.round(Number(member.wallet_balance) * 100) + Math.round(amount * 100);
    let settledAmountCents = 0;
    const [debts] = await connection.query(
      `SELECT id, creditor_member_id, outstanding_amount
       FROM wallet_debts
       WHERE debtor_member_id = ? AND outstanding_amount > 0
       ORDER BY created_at, id
       FOR UPDATE`,
      [member.id],
    );

    for (const debt of debts) {
      if (walletBalanceCents <= 0) break;
      const outstandingCents = Math.round(Number(debt.outstanding_amount) * 100);
      const paymentCents = Math.min(walletBalanceCents, outstandingCents);
      const payment = (paymentCents / 100).toFixed(2);

      const [debtUpdate] = await connection.query(
        'UPDATE wallet_debts SET outstanding_amount = outstanding_amount - ? WHERE id = ? AND outstanding_amount >= ?',
        [payment, debt.id, payment],
      );
      if (debtUpdate.affectedRows !== 1) {
        throw new Error('Wallet debt was not updated');
      }

      const [debtorUpdate] = await connection.query(
        'UPDATE `group_members` SET wallet_balance = wallet_balance - ?, amount_owed = GREATEST(0, amount_owed - ?) WHERE id = ? AND wallet_balance >= ?',
        [payment, payment, member.id, payment],
      );
      const [creditorUpdate] = await connection.query(
        'UPDATE `group_members` SET wallet_balance = wallet_balance + ?, amount_receivable = GREATEST(0, amount_receivable - ?) WHERE id = ?',
        [payment, payment, debt.creditor_member_id],
      );
      if (debtorUpdate.affectedRows !== 1 || creditorUpdate.affectedRows !== 1) {
        throw new Error('Wallet debt payment was not transferred');
      }

      walletBalanceCents -= paymentCents;
      settledAmountCents += paymentCents;
    }

    await connection.commit();
    return res.json({
      message: 'تم شحن المحفظة بنجاح',
      walletBalance: walletBalanceCents / 100,
      settledAmount: settledAmountCents / 100,
    });
  } catch (error) {
    await connection.rollback();
    console.error('Recharge wallet error:', error);
    return res.status(500).json({ error: 'تعذر شحن المحفظة', details: error.message });
  } finally {
    connection.release();
  }
});

app.post('/api/wallet/transfer', getAuthUser, async (req, res) => {
  const sourceGroupId = String(req.body.source_group_id || '');
  const targetGroupId = String(req.body.target_group_id || '');
  const amount = Math.round(Number(req.body.amount) * 100) / 100;

  if (
    !/^[1-9]\d*$/.test(sourceGroupId) ||
    !/^[1-9]\d*$/.test(targetGroupId) ||
    sourceGroupId === targetGroupId ||
    !Number.isFinite(amount) ||
    amount < 0.01
  ) {
    return res.status(400).json({ error: 'بيانات التحويل غير صحيحة' });
  }

  const connection = await db.getConnection();
  try {
    await connection.beginTransaction();
    const [members] = await connection.query(
      `SELECT id, group_id, wallet_balance
       FROM \`group_members\`
       WHERE user_id = ?
         AND status = 'accepted'
         AND group_id IN (?, ?)
       ORDER BY group_id
       FOR UPDATE`,
      [req.user.id, sourceGroupId, targetGroupId],
    );

    const source = members.find(
      (member) => Number(member.group_id) === Number(sourceGroupId),
    );
    const target = members.find(
      (member) => Number(member.group_id) === Number(targetGroupId),
    );

    if (!source || !target) {
      await connection.rollback();
      return res.status(403).json({
        error: 'يجب أن تكون عضواً مقبولاً في مجموعتي المصدر والهدف',
      });
    }

    const sourceBalance = Math.round(Number(source.wallet_balance) * 100) / 100;
    if (sourceBalance < amount) {
      await connection.rollback();
      return res.status(400).json({
        error: `الرصيد غير كافٍ. الرصيد المتاح ${sourceBalance.toFixed(2)} ر.س`,
      });
    }

    const [debit] = await connection.query(
      'UPDATE `group_members` SET wallet_balance = wallet_balance - ? WHERE id = ? AND wallet_balance >= ?',
      [amount.toFixed(2), source.id, amount.toFixed(2)],
    );
    if (debit.affectedRows !== 1) {
      await connection.rollback();
      return res.status(409).json({ error: 'تعذر خصم المبلغ من المحفظة المصدر' });
    }

    const [credit] = await connection.query(
      'UPDATE `group_members` SET wallet_balance = wallet_balance + ? WHERE id = ?',
      [amount.toFixed(2), target.id],
    );
    if (credit.affectedRows !== 1) {
      throw new Error('Target wallet was not credited');
    }

    await connection.commit();
    return res.json({
      message: 'تم تحويل الرصيد وحفظه بنجاح',
      amount,
      sourceBalance: Number((sourceBalance - amount).toFixed(2)),
      targetBalance: Number((Number(target.wallet_balance) + amount).toFixed(2)),
    });
  } catch (error) {
    await connection.rollback();
    console.error('Transfer wallet balance error:', error);
    return res.status(500).json({ error: 'تعذر تحويل الرصيد', details: error.message });
  } finally {
    connection.release();
  }
});

app.get('/api/groups/:groupId/expenses', getAuthUser, async (req, res) => {
  const { groupId } = req.params;

  try {
    const [memberRows] = await db.query(
      'SELECT * FROM `group_members` WHERE group_id = ? AND user_id = ? AND status = "accepted" LIMIT 1',
      [groupId, req.user.id]
    );

    if (memberRows.length === 0) {
      const [groupRows] = await db.query(
        'SELECT * FROM `groups` WHERE id = ? AND owner_user_id = ? LIMIT 1',
        [groupId, req.user.id]
      );

      if (groupRows.length === 0) {
        return res.status(403).json({ error: 'لا يمكنك الوصول إلى هذه المجموعة' });
      }
    }

    const [rows] = await db.query(
      `SELECT e.*, u.name AS payer_name
       FROM \`expenses\` e
       INNER JOIN users u ON u.id = e.payer_user_id
       WHERE e.group_id = ?
       ORDER BY e.created_at DESC`,
      [groupId]
    );

    return res.json({ expenses: rows });
  } catch (error) {
    console.error('Get expenses error:', error);
    return res.status(500).json({ error: 'Failed to load expenses' });
  }
});

app.post('/api/groups/:groupId/expenses', getAuthUser, async (req, res) => {
  const { groupId } = req.params;
  const { title, amount, payer_email, split_emails = [] } = req.body;
  const safeTitle = String(title || '').trim();
  const parsedAmount = Number(amount);
  const safeAmount = Number.isFinite(parsedAmount)
    ? Math.round(parsedAmount * 100) / 100
    : Number.NaN;
  const safePayerEmail = normalizeEmail(payer_email || req.user.email);
  const splitEmails = Array.isArray(split_emails)
    ? [...new Set(split_emails.map(normalizeEmail).filter(Boolean))]
    : null;

  if (
    !/^[1-9]\d*$/.test(groupId) ||
    !safeTitle ||
    !Number.isFinite(safeAmount) ||
    safeAmount < 0.01 ||
    !splitEmails
  ) {
    return res.status(400).json({ error: 'بيانات المصروف غير صحيحة' });
  }

  const connection = await db.getConnection();
  try {
    await connection.beginTransaction();
    const [memberRows] = await connection.query(
      'SELECT gm.id, gm.user_id, gm.email, gm.wallet_balance, u.name FROM `group_members` gm INNER JOIN users u ON u.id = gm.user_id WHERE gm.group_id = ? AND gm.status = "accepted" ORDER BY gm.id FOR UPDATE',
      [groupId],
    );
    if (memberRows.length === 0) {
      const [groupRows] = await connection.query(
        'SELECT * FROM `groups` WHERE id = ? AND owner_user_id = ? LIMIT 1',
        [groupId, req.user.id]
      );
      if (groupRows.length === 0) {
        await connection.rollback();
        return res.status(403).json({ error: 'لا يمكنك إضافة مصاريف لهذه المجموعة' });
      }
    }

    const payer = memberRows.find(
      (member) => normalizeEmail(member.email) === safePayerEmail,
    );
    if (!payer) {
      await connection.rollback();
      return res.status(400).json({ error: 'دافع المصروف ليس عضواً في المجموعة' });
    }
    if (Number(payer.user_id) !== Number(req.user.id)) {
      await connection.rollback();
      return res.status(403).json({ error: 'يمكنك تسجيل القطة باسم حسابك فقط' });
    }

    const membersByEmail = new Map(
      memberRows.map((member) => [normalizeEmail(member.email), member]),
    );
    const splitMembers = splitEmails
      .map((email) => membersByEmail.get(email))
      .filter(Boolean);
    if (splitMembers.length === 0 || splitMembers.length !== splitEmails.length) {
      await connection.rollback();
      return res.status(400).json({ error: 'أعضاء تقسيم المصروف غير صالحين' });
    }

    const [result] = await connection.query(
      'INSERT INTO `expenses` (group_id, title, amount, payer_user_id, payer_email) VALUES (?, ?, ?, ?, ?)',
      [groupId, safeTitle, safeAmount.toFixed(2), payer.user_id, safePayerEmail]
    );

    const totalCents = Math.round(safeAmount * 100);
    const baseShareCents = Math.floor(totalCents / splitMembers.length);
    let remainingCents = totalCents % splitMembers.length;
    let totalPaidCents = 0;
    let totalOwedCents = 0;
    for (const member of splitMembers) {
      const memberShareCents = baseShareCents + (remainingCents > 0 ? 1 : 0);
      if (remainingCents > 0) remainingCents -= 1;
      if (Number(member.id) !== Number(payer.id)) {
        const availableCents = Math.max(
          0,
          Math.round(Number(member.wallet_balance || 0) * 100),
        );
        const paidCents = Math.min(availableCents, memberShareCents);
        const owedCents = memberShareCents - paidCents;

        if (paidCents > 0) {
          const payment = (paidCents / 100).toFixed(2);
          const [debit] = await connection.query(
            'UPDATE `group_members` SET wallet_balance = wallet_balance - ? WHERE id = ? AND wallet_balance >= ?',
            [payment, member.id, payment],
          );
          if (debit.affectedRows !== 1) {
            throw new Error('Member wallet could not be charged');
          }
        }

        if (owedCents > 0) {
          const outstanding = (owedCents / 100).toFixed(2);
          await connection.query(
            'INSERT INTO wallet_debts (expense_id, debtor_member_id, creditor_member_id, outstanding_amount) VALUES (?, ?, ?, ?)',
            [result.insertId, member.id, payer.id, outstanding],
          );
          await connection.query(
            'UPDATE `group_members` SET amount_owed = amount_owed + ? WHERE id = ?',
            [outstanding, member.id],
          );
        }

        totalPaidCents += paidCents;
        totalOwedCents += owedCents;
      }
    }
    if (totalPaidCents > 0 || totalOwedCents > 0) {
      await connection.query(
        'UPDATE `group_members` SET wallet_balance = wallet_balance + ?, amount_receivable = amount_receivable + ? WHERE id = ?',
        [
          (totalPaidCents / 100).toFixed(2),
          (totalOwedCents / 100).toFixed(2),
          payer.id,
        ],
      );
    }

    await connection.commit();
    return res.status(201).json({
      message: 'تم حفظ المصروف بنجاح',
      expense: {
        id: result.insertId,
        group_id: Number(groupId),
        title: safeTitle,
        amount: Number(safeAmount.toFixed(2)),
        payer_user_id: payer.user_id,
        payer_email: safePayerEmail,
        payer_name: payer.name,
        settledAmount: totalPaidCents / 100,
        pendingAmount: totalOwedCents / 100,
      },
    });
  } catch (error) {
    await connection.rollback();
    console.error('Create expense error:', error);
    return res.status(500).json({ error: 'Failed to create expense', details: error.message });
  } finally {
    connection.release();
  }
});

const PORT = 3000;
app.delete('/api/groups/:groupId', getAuthUser, async (req, res) => {
  const { groupId } = req.params;
  if (!/^[1-9]\d*$/.test(groupId)) {
    return res.status(400).json({ error: 'معرف المجموعة غير صالح' });
  }

  try {
    const [groupRows] = await db.query(
      'SELECT owner_user_id FROM `groups` WHERE id = ? LIMIT 1',
      [groupId],
    );
    if (groupRows.length === 0) {
      return res.status(404).json({ error: 'المجموعة غير موجودة' });
    }

    if (Number(groupRows[0].owner_user_id) !== Number(req.user.id)) {
      return res.status(403).json({ error: 'فقط صاحب المجموعة يمكنه حذفها' });
    }

    const [deleteResult] = await db.query(
      'DELETE FROM `groups` WHERE id = ? AND owner_user_id = ?',
      [groupId, req.user.id],
    );
    if (deleteResult.affectedRows === 0) {
      return res.status(404).json({ error: 'المجموعة غير موجودة' });
    }

    return res.json({ message: 'تم حذف المجموعة بنجاح' });
  } catch (error) {
    console.error('Delete group error:', error);
    return res.status(500).json({ error: 'فشل حذف المجموعة', details: error.message });
  }
});

if (require.main === module) {
  ensureDatabaseSchema()
    .then(() => {
      app.listen(PORT, () => {
        console.log(`Backend Server running on http://localhost:${PORT}`);
      });
    })
    .catch((error) => {
      console.error('Database initialization failed:', error);
      process.exit(1);
    });
}

module.exports = {
  app,
  db,
  normalizeEmail,
  matchesRecipientInvitation,
  isPendingRecipientInvitation,
  getUserInvitationRows,
};
