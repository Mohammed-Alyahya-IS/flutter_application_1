const normalizeEmail = (email = '') => String(email).trim().toLowerCase();

const matchesRecipientInvitation = (invitation, userId, email) => {
  if (!invitation) {
    return false;
  }

  const targetUserId = Number(userId ?? 0);
  const targetEmail = normalizeEmail(email ?? '');
  const rowUserId = Number(invitation.user_id ?? 0);
  const rowEmail = normalizeEmail(invitation.email ?? '');

  if (targetUserId > 0 && rowUserId > 0) {
    return rowUserId === targetUserId && rowEmail === targetEmail;
  }

  return rowEmail === targetEmail;
};

const isPendingRecipientInvitation = (invitation, userId, email) => {
  if (!invitation) {
    return false;
  }

  return String(invitation.status || '').toLowerCase() === 'pending' &&
    matchesRecipientInvitation(invitation, userId, email);
};

module.exports = {
  normalizeEmail,
  matchesRecipientInvitation,
  isPendingRecipientInvitation,
};
