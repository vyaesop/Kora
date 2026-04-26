const tokenStorageKey = 'kora_admin_jwt_token';
const userStorageKey = 'kora_admin_user';
const apiBaseStorageKey = 'kora_admin_api_base';

const emailEl = document.getElementById('email');
const passwordEl = document.getElementById('password');
const loginBtn = document.getElementById('loginBtn');
const logoutBtn = document.getElementById('logoutBtn');
const authStatus = document.getElementById('authStatus');
const logBox = document.getElementById('logBox');
const refreshCurrentBtn = document.getElementById('refreshCurrentBtn');

const apiBaseInput = document.getElementById('apiBase');
const saveApiBtn = document.getElementById('saveApiBtn');

const targetUidInput = document.getElementById('targetUid');
const targetAdminInput = document.getElementById('targetAdmin');
const targetSuperAdminInput = document.getElementById('targetSuperAdmin');
const setClaimBtn = document.getElementById('setClaimBtn');

const fundTargetUidInput = document.getElementById('fundTargetUid');
const fundAmountInput = document.getElementById('fundAmount');
const fundNoteInput = document.getElementById('fundNote');
const topUpUserBtn = document.getElementById('topUpUserBtn');

const authBadge = document.getElementById('authBadge');
const apiBadge = document.getElementById('apiBadge');
const pageTitle = document.getElementById('pageTitle');
const pageSubtitle = document.getElementById('pageSubtitle');

const overviewMetrics = document.getElementById('overviewMetrics');
const statusChart = document.getElementById('statusChart');
const verificationChart = document.getElementById('verificationChart');
const topRoutesChart = document.getElementById('topRoutesChart');
const monthlyLoadsChart = document.getElementById('monthlyLoadsChart');
const userMixChart = document.getElementById('userMixChart');
const bidStatusChart = document.getElementById('bidStatusChart');
const recentLoadsList = document.getElementById('recentLoadsList');

const usersList = document.getElementById('usersList');
const disputesList = document.getElementById('disputesList');
const loadsList = document.getElementById('loadsList');
const usersManageList = document.getElementById('usersManageList');

const refreshUsersBtn = document.getElementById('refreshUsersBtn');
const refreshDisputesBtn = document.getElementById('refreshDisputesBtn');
const refreshLoadsBtn = document.getElementById('refreshLoadsBtn');
const refreshUsersManageBtn = document.getElementById('refreshUsersManageBtn');

const loadsSearch = document.getElementById('loadsSearch');
const loadsStatusFilter = document.getElementById('loadsStatusFilter');
const usersSearch = document.getElementById('usersSearch');
const usersRoleFilter = document.getElementById('usersRoleFilter');
const usersVerificationFilter = document.getElementById('usersVerificationFilter');

const navLinks = [...document.querySelectorAll('.nav-link')];
const panels = [...document.querySelectorAll('.panel')];

const injectedApiBase =
  typeof window !== 'undefined' &&
  window.KORA_ADMIN_CONFIG &&
  typeof window.KORA_ADMIN_CONFIG.apiBase === 'string'
    ? window.KORA_ADMIN_CONFIG.apiBase.trim()
    : '';

const isLocalHost =
  typeof window !== 'undefined' &&
  ['localhost', '127.0.0.1'].includes(window.location.hostname);
const defaultApiBase = injectedApiBase || (isLocalHost ? 'http://localhost:3000' : '');
apiBaseInput.value = localStorage.getItem(apiBaseStorageKey) || defaultApiBase;

const panelMeta = {
  overview: {
    title: 'Overview',
    subtitle: 'Live operational visibility across Kora.',
  },
  loads: {
    title: 'Loads',
    subtitle: 'Inspect shipments, bid pressure, and status movement.',
  },
  users: {
    title: 'Users',
    subtitle: 'Search and manage marketplace accounts and roles.',
  },
  moderation: {
    title: 'Moderation',
    subtitle: 'Handle verification and dispute queues in one place.',
  },
  analytics: {
    title: 'Analytics',
    subtitle: 'Monitor route demand, load trends, and operational mix.',
  },
};

let activePanel = 'overview';
let authToken = localStorage.getItem(tokenStorageKey) || '';
let authUser = null;
let dashboardData = null;

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

function setPanel(name) {
  activePanel = name;
  navLinks.forEach((button) => {
    button.classList.toggle('active', button.dataset.panel === name);
  });
  panels.forEach((panel) => {
    panel.classList.toggle('active', panel.dataset.panel === name);
  });

  const meta = panelMeta[name] || panelMeta.overview;
  pageTitle.textContent = meta.title;
  pageSubtitle.textContent = meta.subtitle;
}

function updateApiBadge() {
  apiBadge.textContent = getApiBase() || 'Not set';
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
  authBadge.textContent = signedIn
    ? authUser.isSuperAdmin
      ? 'Super admin'
      : 'Admin'
    : 'Signed out';
  topUpUserBtn.disabled = !authUser?.isSuperAdmin;
}

function setAuthMessage(message) {
  authStatus.textContent = message;
}

function formatNumber(value, fractionDigits = 0) {
  return new Intl.NumberFormat('en-US', {
    minimumFractionDigits: fractionDigits,
    maximumFractionDigits: fractionDigits,
  }).format(Number(value || 0));
}

function formatWeight(value, unit) {
  const numeric = Number(value);
  if (!Number.isFinite(numeric)) {
    return '-';
  }
  return `${new Intl.NumberFormat('en-US', {
    minimumFractionDigits: 0,
    maximumFractionDigits: 1,
  }).format(numeric)} ${unit || 'kg'}`.trim();
}

function formatPrice(value) {
  const numeric = Number(value || 0);
  return new Intl.NumberFormat('en-US', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(numeric);
}

function formatDate(value) {
  if (!value) {
    return 'n/a';
  }
  try {
    return new Date(value).toLocaleString();
  } catch {
    return 'n/a';
  }
}

function formatRouteDisplay(item) {
  return item.routeDisplay || `${item.startDisplay || item.start || 'Unknown'} -> ${item.endDisplay || item.end || 'Unknown'}`;
}

function formatLocationMeta(item) {
  return `${item.startDisplay || item.start || 'Unknown'} -> ${item.endDisplay || item.end || 'Unknown'}`;
}

function escapeHtml(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

function verificationLabel(status) {
  switch (String(status || '').trim().toLowerCase()) {
    case 'pending':
    case 'submitted':
      return 'In review';
    case 'approved':
      return 'Approved';
    case 'rejected':
      return 'Rejected';
    default:
      return 'Not submitted';
  }
}

function renderDocumentCard(label, source) {
  const hasSource = Boolean(String(source || '').trim());
  return `
    <div class="document-card ${hasSource ? '' : 'document-card-empty'}">
      <div class="document-preview">
        ${
          hasSource
            ? `<img src="${escapeHtml(source)}" alt="${escapeHtml(label)}" />`
            : '<span>No file</span>'
        }
      </div>
      <div class="document-meta">
        <strong>${escapeHtml(label)}</strong>
        <span>${hasSource ? 'Uploaded' : 'Missing'}</span>
      </div>
    </div>
  `;
}

function renderVerificationDocuments(user) {
  const documents = [
    user.tinNumber
      ? `
        <div class="document-card">
          <div class="document-preview"><span>${escapeHtml(user.tinNumber)}</span></div>
          <div class="document-meta">
            <strong>TIN number</strong>
            <span>Added</span>
          </div>
        </div>
      `
      : `
        <div class="document-card document-card-empty">
          <div class="document-preview"><span>No value</span></div>
          <div class="document-meta">
            <strong>TIN number</strong>
            <span>Missing</span>
          </div>
        </div>
      `,
    user.userType === 'Driver'
      ? user.libre
        ? `
          <div class="document-card">
            <div class="document-preview"><span>${escapeHtml(user.libre)}</span></div>
            <div class="document-meta">
              <strong>Libre</strong>
              <span>Added</span>
            </div>
          </div>
        `
        : `
          <div class="document-card document-card-empty">
            <div class="document-preview"><span>No value</span></div>
            <div class="document-meta">
              <strong>Libre</strong>
              <span>Missing</span>
            </div>
          </div>
        `
      : '',
    user.userType === 'Driver'
      ? user.licensePlate
        ? `
          <div class="document-card">
            <div class="document-preview"><span>${escapeHtml(user.licensePlate)}</span></div>
            <div class="document-meta">
              <strong>Vehicle plate number</strong>
              <span>Added</span>
            </div>
          </div>
        `
        : `
          <div class="document-card document-card-empty">
            <div class="document-preview"><span>No value</span></div>
            <div class="document-meta">
              <strong>Vehicle plate number</strong>
              <span>Missing</span>
            </div>
          </div>
        `
      : '',
    renderDocumentCard('National ID', user.idPhoto),
    user.userType === 'Driver'
      ? renderDocumentCard("Driver's license", user.licenseNumberPhoto)
      : '',
    user.userType === 'Cargo'
      ? renderDocumentCard(
          'Trade registration certificate',
          user.tradeRegistrationCertificatePhoto,
        )
      : '',
    renderDocumentCard('Trade licence photo', user.tradeLicensePhoto),
  ]
    .filter(Boolean)
    .join('');

  return `<div class="document-grid">${documents}</div>`;
}

async function callAdmin(path, options = {}) {
  if (!authToken) {
    throw new Error('Not signed in');
  }

  const apiBase = getApiBase();
  if (!apiBase) {
    throw new Error('Set API base URL first');
  }

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

function renderMetrics(container, overview) {
  const metrics = [
    {
      label: 'Users',
      value: formatNumber(overview?.users || 0),
      hint: 'Total marketplace accounts',
    },
    {
      label: 'Loads',
      value: formatNumber(overview?.threads || 0),
      hint: 'Shipments posted to date',
    },
    {
      label: 'Bids',
      value: formatNumber(overview?.bids || 0),
      hint: 'Bids submitted across all loads',
    },
    {
      label: 'Average bid',
      value: formatPrice(overview?.averageBidAmount || 0),
      hint: 'Mean offer amount across all bids',
    },
  ];

  container.innerHTML = metrics
    .map(
      (metric) => `
        <article class="metric-card">
          <span class="metric-label">${metric.label}</span>
          <strong class="metric-value">${metric.value}</strong>
          <span class="metric-hint">${metric.hint}</span>
        </article>
      `,
    )
    .join('');
}

function renderBarChart(container, items, valueFormatter = (value) => formatNumber(value)) {
  const maxValue = Math.max(1, ...items.map((item) => Number(item.count || 0)));
  container.innerHTML = items.length
    ? items
        .map((item) => {
          const count = Number(item.count || 0);
          const width = `${Math.max(8, (count / maxValue) * 100)}%`;
          return `
            <div class="chart-row">
              <div class="chart-head">
                <span class="chart-label">${escapeHtml(item.label || item.route)}</span>
                <span class="chart-value">${valueFormatter(count)}</span>
              </div>
              <div class="chart-rail">
                <div class="chart-fill" style="width:${width}"></div>
              </div>
            </div>
          `;
        })
        .join('')
    : '<div class="item">No data available yet.</div>';
}

function renderRecentLoads(loads) {
  recentLoadsList.innerHTML = loads.length
    ? loads
        .map(
          (load) => `
            <article class="item">
              <div class="item-title">${escapeHtml(load.message || formatRouteDisplay(load))}</div>
              <div class="item-sub">${escapeHtml(load.owner?.name || 'Unknown shipper')} • ${escapeHtml(load.start || 'Unknown')} -> ${escapeHtml(load.end || 'Unknown')}</div>
              <div class="item-meta">
                <span class="tag">Status: ${escapeHtml(load.deliveryStatus || 'pending_bids')}</span>
                <span class="tag">Weight: ${escapeHtml(formatWeight(load.weight, load.weightUnit || 'kg'))}</span>
                <span class="tag">Bids: ${formatNumber(load.bidsCount || 0)}</span>
                <span class="tag">Best bid: ${load.bestBidAmount == null ? 'n/a' : formatPrice(load.bestBidAmount)}</span>
              </div>
            </article>
          `,
        )
        .join('')
    : '<div class="item">No recent loads available.</div>';
}

function renderLoadRows(loads) {
  loadsList.innerHTML = loads.length
    ? loads
        .map(
          (load) => `
            <article class="item">
              <div class="item-title">${escapeHtml(load.message || formatRouteDisplay(load))}</div>
              <div class="item-sub">${escapeHtml(load.start || 'Unknown')} -> ${escapeHtml(load.end || 'Unknown')} • Owner: ${escapeHtml(load.owner?.name || 'Unknown')}</div>
              <div class="item-meta">
                <span class="tag">Status: ${escapeHtml(load.deliveryStatus || 'pending_bids')}</span>
                <span class="tag">Weight: ${escapeHtml(formatWeight(load.weight, load.weightUnit || 'kg'))}</span>
                <span class="tag">Bids: ${formatNumber(load.bidsCount || 0)}</span>
                <span class="tag">Disputes: ${formatNumber(load.disputesCount || 0)}</span>
                <span class="tag">Best bid: ${load.bestBidAmount == null ? 'n/a' : formatPrice(load.bestBidAmount)}</span>
                <span class="tag">Created: ${escapeHtml(formatDate(load.createdAt))}</span>
              </div>
            </article>
          `,
        )
        .join('')
    : '<div class="item">No loads match the current filters.</div>';
}

function renderPendingUsers(users) {
  usersList.innerHTML = users.length
    ? users
        .map(
          (user) => `
            <article class="item">
              <div class="item-title">${escapeHtml(user.name || 'Unnamed')}</div>
              <div class="item-sub">${escapeHtml(user.email || 'n/a')} • ${escapeHtml(user.userType || 'n/a')}</div>
              <div class="item-meta">
                <span class="tag">Verification: ${escapeHtml(verificationLabel(user.verificationStatus))}</span>
                <span class="tag">User ID: ${escapeHtml(user.id)}</span>
                ${
                  user.phoneNumber
                    ? `<span class="tag">Phone: ${escapeHtml(user.phoneNumber)}</span>`
                    : ''
                }
                ${
                  user.tinNumber
                    ? `<span class="tag">TIN: ${escapeHtml(user.tinNumber)}</span>`
                    : ''
                }
                ${
                  user.libre
                    ? `<span class="tag">Libre: ${escapeHtml(user.libre)}</span>`
                    : ''
                }
                ${
                  user.licensePlate
                    ? `<span class="tag">Plate: ${escapeHtml(user.licensePlate)}</span>`
                    : ''
                }
                ${
                  user.verificationSubmittedAt
                    ? `<span class="tag">Submitted: ${escapeHtml(formatDate(user.verificationSubmittedAt))}</span>`
                    : ''
                }
              </div>
              ${renderVerificationDocuments(user)}
              ${
                user.verificationNote
                  ? `<div class="item-sub"><strong>Status note:</strong> ${escapeHtml(user.verificationNote)}</div>`
                  : ''
              }
              <div class="item-actions">
                <button data-action="approve-user" data-user-id="${escapeHtml(user.id)}">Approve</button>
                <button class="danger" data-action="reject-user" data-user-id="${escapeHtml(user.id)}">Reject</button>
              </div>
            </article>
          `,
        )
        .join('')
    : '<div class="item">No pending verification users.</div>';
}

function renderDisputes(disputes) {
  disputesList.innerHTML = disputes.length
    ? disputes
        .map(
          (entry) => `
            <article class="item">
              <div class="item-title">${escapeHtml(entry.category || 'General dispute')}</div>
              <div class="item-sub">Thread: ${escapeHtml(entry.threadId || 'n/a')} • Reporter: ${escapeHtml(entry.reporterId || 'n/a')}</div>
              <div class="item-sub">${escapeHtml(entry.details || 'No detail supplied')}</div>
              <div class="item-meta">
                <span class="tag">Status: ${escapeHtml(entry.status || 'open')}</span>
                <span class="tag">Created: ${escapeHtml(formatDate(entry.createdAt))}</span>
              </div>
              <div class="item-actions">
                <button data-action="resolve-dispute" data-thread-id="${escapeHtml(entry.threadId)}" data-dispute-id="${escapeHtml(entry.id)}">Resolve</button>
                <button class="warn" data-action="review-dispute" data-thread-id="${escapeHtml(entry.threadId)}" data-dispute-id="${escapeHtml(entry.id)}">Mark In Review</button>
              </div>
            </article>
          `,
        )
        .join('')
    : '<div class="item">No open disputes.</div>';
}

function renderUsersManage(users) {
  usersManageList.innerHTML = users.length
    ? users
        .map((user) => {
          const claimButtons = authUser?.isSuperAdmin
            ? `
                <div class="item-actions">
                  <button
                    data-action="set-claim"
                    data-user-id="${escapeHtml(user.id)}"
                    data-admin="true"
                    data-super-admin="${user.isSuperAdmin ? 'true' : 'false'}"
                  >
                    ${user.isAdmin ? 'Keep admin' : 'Make admin'}
                  </button>
                  <button
                    class="ghost"
                    data-action="set-claim"
                    data-user-id="${escapeHtml(user.id)}"
                    data-admin="false"
                    data-super-admin="false"
                  >
                    Remove admin
                  </button>
                  ${
                    user.isSuperAdmin
                      ? ''
                      : `
                        <button
                          class="secondary"
                          data-action="set-claim"
                          data-user-id="${escapeHtml(user.id)}"
                          data-admin="true"
                          data-super-admin="true"
                        >
                          Promote to super admin
                        </button>
                      `
                  }
                </div>
              `
            : '';

          return `
            <article class="item">
              <div class="item-title">${escapeHtml(user.name || 'Unnamed')}</div>
              <div class="item-sub">${escapeHtml(user.email || 'n/a')} • ${escapeHtml(user.userType || 'n/a')}</div>
              <div class="item-meta">
                <span class="tag">Verification: ${escapeHtml(verificationLabel(user.verificationStatus))}</span>
                <span class="tag">Role: ${
                  user.isSuperAdmin ? 'Super admin' : user.isAdmin ? 'Admin' : 'Standard'
                }</span>
                <span class="tag">Joined: ${escapeHtml(formatDate(user.createdAt))}</span>
                ${
                  user.verificationSubmittedAt
                    ? `<span class="tag">Submitted: ${escapeHtml(formatDate(user.verificationSubmittedAt))}</span>`
                    : ''
                }
                ${
                  user.phoneNumber
                    ? `<span class="tag">Phone: ${escapeHtml(user.phoneNumber)}</span>`
                    : ''
                }
                ${
                  user.tinNumber
                    ? `<span class="tag">TIN: ${escapeHtml(user.tinNumber)}</span>`
                    : ''
                }
                ${
                  user.libre
                    ? `<span class="tag">Libre: ${escapeHtml(user.libre)}</span>`
                    : ''
                }
                ${
                  user.licensePlate
                    ? `<span class="tag">Plate: ${escapeHtml(user.licensePlate)}</span>`
                    : ''
                }
                ${
                  user.address
                    ? `<span class="tag">Address: ${escapeHtml(user.address)}</span>`
                    : ''
                }
                ${
                  user.truckType
                    ? `<span class="tag">Truck: ${escapeHtml(user.truckType)}</span>`
                    : ''
                }
              </div>
              ${renderVerificationDocuments(user)}
              ${
                user.verificationNote
                  ? `<div class="item-sub"><strong>Review note:</strong> ${escapeHtml(user.verificationNote)}</div>`
                  : ''
              }
              ${claimButtons}
            </article>
          `;
        })
        .join('')
    : '<div class="item">No users match the current filters.</div>';
}

async function loadDashboard() {
  const data = await callAdmin('/api/admin/dashboard');
  dashboardData = data;

  renderMetrics(overviewMetrics, data.overview);
  renderBarChart(statusChart, data.loadStatus || []);
  renderBarChart(verificationChart, data.verification || []);
  renderBarChart(topRoutesChart, data.topRoutes || []);
  renderBarChart(monthlyLoadsChart, data.monthlyLoads || []);
  renderBarChart(userMixChart, data.userMix || []);
  renderBarChart(bidStatusChart, data.bidStatus || []);
  renderRecentLoads(data.recentLoads || []);
}

async function loadPendingUsers() {
  const data = await callAdmin('/api/admin/users/pending-verification');
  renderPendingUsers(data.users || []);
}

async function loadDisputes() {
  const data = await callAdmin('/api/admin/disputes?status=open');
  renderDisputes(data.disputes || []);
}

async function loadLoads() {
  const params = new URLSearchParams();
  if (loadsSearch.value.trim()) {
    params.set('search', loadsSearch.value.trim());
  }
  if (loadsStatusFilter.value) {
    params.set('status', loadsStatusFilter.value);
  }
  params.set('limit', '60');

  const data = await callAdmin(`/api/admin/loads?${params.toString()}`);
  renderLoadRows(data.loads || []);
}

async function loadUsersManage() {
  const params = new URLSearchParams();
  if (usersSearch.value.trim()) {
    params.set('search', usersSearch.value.trim());
  }
  if (usersRoleFilter.value) {
    params.set('role', usersRoleFilter.value);
  }
  if (usersVerificationFilter.value) {
    params.set('verificationStatus', usersVerificationFilter.value);
  }
  params.set('limit', '60');

  const data = await callAdmin(`/api/admin/users?${params.toString()}`);
  renderUsersManage(data.users || []);
}

async function refreshActivePanel() {
  if (!authToken) {
    return;
  }

  try {
    if (activePanel === 'overview' || activePanel === 'analytics') {
      await loadDashboard();
    }
    if (activePanel === 'loads') {
      await loadLoads();
    }
    if (activePanel === 'users') {
      await loadUsersManage();
    }
    if (activePanel === 'moderation') {
      await Promise.all([loadPendingUsers(), loadDisputes()]);
    }
    log(`Refreshed ${activePanel} view.`);
  } catch (error) {
    log(`Refresh failed: ${error.message}`);
  }
}

async function setUserClaim(userId, admin, superAdmin) {
  await callAdmin(`/api/admin/admins/${userId}/claim`, {
    method: 'PATCH',
    body: {
      admin,
      superAdmin,
    },
  });
}

async function topUpUserWallet() {
  const userId = String(fundTargetUidInput.value || '').trim();
  const amount = Number(fundAmountInput.value || 0);
  const note = String(fundNoteInput.value || '').trim();

  if (!userId) {
    log('Cannot add funds: target user UID is required.');
    return;
  }

  if (!Number.isFinite(amount) || amount <= 0) {
    log('Cannot add funds: amount must be greater than zero.');
    return;
  }

  try {
    await callAdmin(`/api/admin/users/${encodeURIComponent(userId)}/wallet/topups`, {
      method: 'POST',
      body: {
        amount,
        note: note || undefined,
      },
    });
    log(`Added ${formatPrice(amount)} ETB to user ${userId}'s wallet.`);
    fundAmountInput.value = '';
    fundNoteInput.value = '';
  } catch (error) {
    log(`Wallet top-up failed for ${userId}: ${error.message}`);
    throw error;
  }
}

async function bootstrapAdminData() {
  if (!authToken) {
    return;
  }

  await Promise.all([
    loadDashboard(),
    loadLoads(),
    loadUsersManage(),
    loadPendingUsers(),
    loadDisputes(),
  ]);
}

navLinks.forEach((button) => {
  button.addEventListener('click', async () => {
    setPanel(button.dataset.panel);
    await refreshActivePanel();
  });
});

saveApiBtn.addEventListener('click', () => {
  localStorage.setItem(apiBaseStorageKey, apiBaseInput.value.trim());
  updateApiBadge();
  setAuthMessage(authToken && authUser ? authStatus.textContent : 'API base saved.');
  log('Saved API base URL.');
});

setClaimBtn.addEventListener('click', async () => {
  const targetUid = (targetUidInput.value || '').trim();
  if (!targetUid) {
    log('Set claim failed: target UID is required.');
    return;
  }

  try {
    await setUserClaim(
      targetUid,
      targetAdminInput.checked,
      targetSuperAdminInput.checked,
    );
    log(
      `Updated claim for ${targetUid}: admin=${targetAdminInput.checked}, superAdmin=${targetSuperAdminInput.checked}`,
    );
    await loadUsersManage();
  } catch (error) {
    log(`Set claim failed: ${error.message}`);
  }
});

loginBtn.addEventListener('click', async () => {
  loginBtn.disabled = true;
  try {
    const apiBase = getApiBase();
    if (!apiBase) {
      setAuthMessage('Set the backend API base URL first.');
      log('Set API base URL first.');
      return;
    }

    setAuthMessage('Signing in...');

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
    await bootstrapAdminData();
    setAuthMessage(
      `Signed in as ${data.user.email}${data.user.isSuperAdmin ? ' (super admin)' : ''}`,
    );
    log('Signed in successfully.');
  } catch (error) {
    const message =
      error instanceof Error && error.message === 'Failed to fetch'
        ? 'Sign in failed: could not reach the backend. Check API base and backend CORS.'
        : `Sign in failed: ${error.message}`;
    setAuthMessage(message);
    log(`Sign in failed: ${error.message}`);
  } finally {
    loginBtn.disabled = false;
  }
});

logoutBtn.addEventListener('click', () => {
  setAuthState('', null);
  dashboardData = null;
  overviewMetrics.innerHTML = '';
  statusChart.innerHTML = '';
  verificationChart.innerHTML = '';
  topRoutesChart.innerHTML = '';
  monthlyLoadsChart.innerHTML = '';
  userMixChart.innerHTML = '';
  bidStatusChart.innerHTML = '';
  recentLoadsList.innerHTML = '';
  usersList.innerHTML = '';
  disputesList.innerHTML = '';
  loadsList.innerHTML = '';
  usersManageList.innerHTML = '';
  log('Signed out.');
});

refreshCurrentBtn.addEventListener('click', refreshActivePanel);
refreshUsersBtn.addEventListener('click', loadPendingUsers);
refreshDisputesBtn.addEventListener('click', loadDisputes);
refreshLoadsBtn.addEventListener('click', loadLoads);
refreshUsersManageBtn.addEventListener('click', loadUsersManage);
topUpUserBtn.addEventListener('click', async () => {
  try {
    await topUpUserWallet();
  } catch (error) {
    // error already logged by topUpUserWallet
  }
});

loadsSearch.addEventListener('keydown', (event) => {
  if (event.key === 'Enter') {
    loadLoads().catch((error) => log(`Load refresh failed: ${error.message}`));
  }
});

usersSearch.addEventListener('keydown', (event) => {
  if (event.key === 'Enter') {
    loadUsersManage().catch((error) => log(`User refresh failed: ${error.message}`));
  }
});

loadsStatusFilter.addEventListener('change', () => {
  loadLoads().catch((error) => log(`Load refresh failed: ${error.message}`));
});

usersRoleFilter.addEventListener('change', () => {
  loadUsersManage().catch((error) => log(`User refresh failed: ${error.message}`));
});

usersVerificationFilter.addEventListener('change', () => {
  loadUsersManage().catch((error) => log(`User refresh failed: ${error.message}`));
});

usersList.addEventListener('click', async (event) => {
  const button = event.target.closest('button[data-action]');
  if (!button) {
    return;
  }

  const userId = button.dataset.userId;
  if (!userId) {
    return;
  }

  try {
    if (button.dataset.action === 'approve-user') {
      const note =
        window.prompt('Optional approval note for the user profile:', 'Approved by admin panel') ||
        'Approved by admin panel';
      await callAdmin(`/api/admin/users/${userId}/verification`, {
        method: 'PATCH',
        body: { status: 'approved', note },
      });
      log(`Approved user ${userId}`);
      await loadPendingUsers();
      await loadUsersManage();
      await loadDashboard();
    }

    if (button.dataset.action === 'reject-user') {
      const note =
        window.prompt('Add a rejection note so the user knows what to fix:', 'Please upload clearer documents and resubmit.') ||
        'Rejected by admin panel';
      await callAdmin(`/api/admin/users/${userId}/verification`, {
        method: 'PATCH',
        body: { status: 'rejected', note },
      });
      log(`Rejected user ${userId}`);
      await loadPendingUsers();
      await loadUsersManage();
      await loadDashboard();
    }
  } catch (error) {
    log(`User moderation failed: ${error.message}`);
  }
});

disputesList.addEventListener('click', async (event) => {
  const button = event.target.closest('button[data-action]');
  if (!button) {
    return;
  }

  const threadId = button.dataset.threadId;
  const disputeId = button.dataset.disputeId;
  if (!threadId || !disputeId) {
    return;
  }

  try {
    if (button.dataset.action === 'resolve-dispute') {
      await callAdmin(`/api/admin/threads/${threadId}/disputes/${disputeId}`, {
        method: 'PATCH',
        body: {
          status: 'resolved',
          resolutionNote: 'Resolved by admin panel',
        },
      });
      log(`Resolved dispute ${disputeId}`);
    }

    if (button.dataset.action === 'review-dispute') {
      await callAdmin(`/api/admin/threads/${threadId}/disputes/${disputeId}`, {
        method: 'PATCH',
        body: {
          status: 'in_review',
          resolutionNote: 'Moved to in-review by admin panel',
        },
      });
      log(`Moved dispute ${disputeId} to in review`);
    }

    await loadDisputes();
    await loadDashboard();
  } catch (error) {
    log(`Dispute update failed: ${error.message}`);
  }
});

usersManageList.addEventListener('click', async (event) => {
  const button = event.target.closest('button[data-action="set-claim"]');
  if (!button) {
    return;
  }

  const userId = button.dataset.userId;
  if (!userId) {
    return;
  }

  try {
    await setUserClaim(
      userId,
      button.dataset.admin === 'true',
      button.dataset.superAdmin === 'true',
    );
    log(
      `Updated claims for ${userId}: admin=${button.dataset.admin}, superAdmin=${button.dataset.superAdmin}`,
    );
    await loadUsersManage();
    await loadDashboard();
  } catch (error) {
    log(`Claim update failed: ${error.message}`);
  }
});

async function hydrateSession() {
  if (!authToken) {
    setAuthState('', null);
    return;
  }

  try {
    const me = await callAdmin('/api/auth/me');
    setAuthState(authToken, me.user);
    await bootstrapAdminData();
  } catch {
    setAuthState('', null);
  }
}

setPanel(activePanel);
setAuthState(authToken, authUser);
updateApiBadge();
if (!getApiBase()) {
  setAuthMessage('Set your backend API base URL to enable sign in.');
}
hydrateSession();
