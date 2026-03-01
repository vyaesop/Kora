const tokenStorageKey = 'kora_admin_jwt_token';
const userStorageKey = 'kora_admin_user';
const apiBaseStorageKey = 'kora_admin_api_base';

const emailEl = document.getElementById('email');
const passwordEl = document.getElementById('password');
const loginBtn = document.getElementById('loginBtn');
const logoutBtn = document.getElementById('logoutBtn');
const authStatus = document.getElementById('authStatus');
const usersList = document.getElementById('usersList');
const disputesList = document.getElementById('disputesList');
const logBox = document.getElementById('logBox');
const refreshUsersBtn = document.getElementById('refreshUsersBtn');
const refreshDisputesBtn = document.getElementById('refreshDisputesBtn');
const apiBaseInput = document.getElementById('apiBase');
const saveApiBtn = document.getElementById('saveApiBtn');
const targetUidInput = document.getElementById('targetUid');
const targetAdminInput = document.getElementById('targetAdmin');
const targetSuperAdminInput = document.getElementById('targetSuperAdmin');
const setClaimBtn = document.getElementById('setClaimBtn');

apiBaseInput.value = localStorage.getItem(apiBaseStorageKey) || '';

let authToken = localStorage.getItem(tokenStorageKey) || '';
let authUser = null;

try {
  const storedUser = localStorage.getItem(userStorageKey);
  authUser = storedUser ? JSON.parse(storedUser) : null;
} catch {
  authUser = null;
}

function getApiBase() {
  return (apiBaseInput.value || '').trim().replace(/\/+$/, '');
}

function log(message) {
  const at = new Date().toISOString();
  logBox.textContent = `[${at}] ${message}\n${logBox.textContent}`;
}

function setAuthState(token, user) {
  authToken = token || '';
  authUser = user || null;

  if (authToken) {
    localStorage.setItem(tokenStorageKey, authToken);
  } else {
    localStorage.removeItem(tokenStorageKey);
  }

  if (authUser) {
    localStorage.setItem(userStorageKey, JSON.stringify(authUser));
  } else {
    localStorage.removeItem(userStorageKey);
  }

  const signedIn = Boolean(authToken && authUser);
  loginBtn.disabled = signedIn;
  logoutBtn.disabled = !signedIn;
  authStatus.textContent = signedIn
    ? `Signed in as ${authUser.email}${authUser.isSuperAdmin ? ' (super admin)' : ''}`
    : 'Not signed in';
}

saveApiBtn.addEventListener('click', () => {
  localStorage.setItem(apiBaseStorageKey, apiBaseInput.value.trim());
  log('Saved API base URL.');
});

async function callAdmin(path, options = {}) {
  if (!authToken) throw new Error('Not signed in');

  const apiBase = getApiBase();
  if (!apiBase) throw new Error('Set API base URL first');

  const response = await fetch(`${apiBase}${path}`, {
    method: options.method || 'GET',
    headers: {
      Authorization: `Bearer ${authToken}`,
      'Content-Type': 'application/json',
      ...(options.headers || {}),
    },
    body: options.body ? JSON.stringify(options.body) : undefined,
  });

  const data = await response.json().catch(() => ({}));
  if (!response.ok || data.ok === false) {
    throw new Error(data.error || `HTTP ${response.status}`);
  }
  return data;
}

async function loadPendingUsers() {
  usersList.innerHTML = '';
  try {
    const { users } = await callAdmin('/api/admin/users/pending-verification');
    if (!users?.length) {
      usersList.innerHTML = '<div class="item">No pending verification users.</div>';
      return;
    }

    users.forEach((user) => {
      const item = document.createElement('div');
      item.className = 'item';
      item.innerHTML = `
        <div class="item-title">${user.name || 'Unnamed'} (${user.id})</div>
        <div class="item-sub">Email: ${user.email || 'n/a'} | Type: ${user.userType || 'n/a'}</div>
      `;

      const actions = document.createElement('div');
      actions.className = 'item-actions';

      const approve = document.createElement('button');
      approve.textContent = 'Approve';
      approve.onclick = async () => {
        try {
          await callAdmin(`/api/admin/users/${user.id}/verification`, {
            method: 'PATCH',
            body: { status: 'approved', note: 'Approved by admin console' },
          });
          log(`Approved user ${user.id}`);
          await loadPendingUsers();
        } catch (e) {
          log(`Approve failed: ${e.message}`);
        }
      };

      const reject = document.createElement('button');
      reject.className = 'secondary';
      reject.textContent = 'Reject';
      reject.onclick = async () => {
        try {
          await callAdmin(`/api/admin/users/${user.id}/verification`, {
            method: 'PATCH',
            body: { status: 'rejected', note: 'Rejected by admin console' },
          });
          log(`Rejected user ${user.id}`);
          await loadPendingUsers();
        } catch (e) {
          log(`Reject failed: ${e.message}`);
        }
      };

      actions.appendChild(approve);
      actions.appendChild(reject);
      item.appendChild(actions);
      usersList.appendChild(item);
    });
  } catch (e) {
    usersList.innerHTML = `<div class="item">Error: ${e.message}</div>`;
    log(`Load users failed: ${e.message}`);
  }
}

async function loadDisputes() {
  disputesList.innerHTML = '';
  try {
    const { disputes } = await callAdmin('/api/admin/disputes?status=open');
    if (!disputes?.length) {
      disputesList.innerHTML = '<div class="item">No open disputes.</div>';
      return;
    }

    disputes.forEach((entry) => {
      const item = document.createElement('div');
      item.className = 'item';
      item.innerHTML = `
        <div class="item-title">Thread: ${entry.threadId || 'n/a'} | Dispute: ${entry.id}</div>
        <div class="item-sub">Category: ${entry.category || 'n/a'} | Reporter: ${entry.reporterId || 'n/a'}</div>
        <div class="item-sub">${entry.details || ''}</div>
      `;

      const actions = document.createElement('div');
      actions.className = 'item-actions';

      const resolve = document.createElement('button');
      resolve.textContent = 'Mark Resolved';
      resolve.onclick = async () => {
        try {
          await callAdmin(`/api/admin/threads/${entry.threadId}/disputes/${entry.id}`, {
            method: 'PATCH',
            body: {
              status: 'resolved',
              resolutionNote: 'Resolved by admin console',
            },
          });
          log(`Resolved dispute ${entry.id}`);
          await loadDisputes();
        } catch (e) {
          log(`Resolve failed: ${e.message}`);
        }
      };

      const review = document.createElement('button');
      review.className = 'secondary';
      review.textContent = 'Mark In Review';
      review.onclick = async () => {
        try {
          await callAdmin(`/api/admin/threads/${entry.threadId}/disputes/${entry.id}`, {
            method: 'PATCH',
            body: {
              status: 'in_review',
              resolutionNote: 'Moved to in-review by admin console',
            },
          });
          log(`Marked in_review dispute ${entry.id}`);
          await loadDisputes();
        } catch (e) {
          log(`In review failed: ${e.message}`);
        }
      };

      actions.appendChild(resolve);
      actions.appendChild(review);
      item.appendChild(actions);
      disputesList.appendChild(item);
    });
  } catch (e) {
    disputesList.innerHTML = `<div class="item">Error: ${e.message}</div>`;
    log(`Load disputes failed: ${e.message}`);
  }
}

setClaimBtn.addEventListener('click', async () => {
  const targetUid = (targetUidInput.value || '').trim();
  if (!targetUid) {
    log('Set claim failed: target UID is required.');
    return;
  }

  try {
    await callAdmin(`/api/admin/admins/${targetUid}/claim`, {
      method: 'PATCH',
      body: {
        admin: targetAdminInput.checked,
        superAdmin: targetSuperAdminInput.checked,
      },
    });
    log(`Updated claim for ${targetUid}: admin=${targetAdminInput.checked}, superAdmin=${targetSuperAdminInput.checked}`);
  } catch (e) {
    log(`Set claim failed: ${e.message}`);
  }
});

loginBtn.addEventListener('click', async () => {
  try {
    const apiBase = getApiBase();
    if (!apiBase) {
      log('Set API base URL first. Example: https://your-backend-url');
      return;
    }

    const response = await fetch(`${apiBase}/api/auth/login`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        email: emailEl.value.trim(),
        password: passwordEl.value,
      }),
    });

    const data = await response.json().catch(() => ({}));
    if (!response.ok || !data?.token || !data?.user) {
      throw new Error(data.error || `HTTP ${response.status}`);
    }

    setAuthState(data.token, data.user);
    await loadPendingUsers();
    await loadDisputes();
    log('Signed in successfully.');
  } catch (e) {
    log(`Sign in failed: ${e.message}`);
  }
});

logoutBtn.addEventListener('click', async () => {
  setAuthState('', null);
  usersList.innerHTML = '';
  disputesList.innerHTML = '';
  log('Signed out.');
});

refreshUsersBtn.addEventListener('click', loadPendingUsers);
refreshDisputesBtn.addEventListener('click', loadDisputes);

async function hydrateSession() {
  if (!authToken) {
    setAuthState('', null);
    return;
  }

  try {
    const me = await callAdmin('/api/auth/me');
    setAuthState(authToken, me.user);
    await loadPendingUsers();
    await loadDisputes();
  } catch {
    setAuthState('', null);
    usersList.innerHTML = '';
    disputesList.innerHTML = '';
  }
}

setAuthState(authToken, authUser);
hydrateSession();
