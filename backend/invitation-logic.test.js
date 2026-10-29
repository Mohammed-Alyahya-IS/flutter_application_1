const assert = require('node:assert/strict');
const { normalizeEmail, matchesRecipientInvitation, isPendingRecipientInvitation } = require('./invitation-logic');

assert.equal(normalizeEmail('  User@Example.com  '), 'user@example.com');
assert.equal(
  matchesRecipientInvitation({ user_id: 7, email: 'user@example.com' }, 7, 'user@example.com'),
  true,
);
assert.equal(
  matchesRecipientInvitation({ user_id: 99, email: 'sender@example.com' }, 7, 'user@example.com'),
  false,
);
assert.equal(
  isPendingRecipientInvitation({ status: 'pending', user_id: 7, email: 'user@example.com' }, 7, 'user@example.com'),
  true,
);
assert.equal(
  isPendingRecipientInvitation({ status: 'accepted', user_id: 7, email: 'user@example.com' }, 7, 'user@example.com'),
  false,
);

console.log('invitation logic checks passed');
