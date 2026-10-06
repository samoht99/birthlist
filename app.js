// Ces deux valeurs sont publiques par conception (la sécurité repose sur la base).
const SUPABASE_URL = "https://bwcizhvhtwkjfjadurcj.supabase.co";
const SUPABASE_KEY = "sb_publishable_KLQZ-MuQKYbV1_GUvOFk9Q_nfumGtNc";

const SUPABASE_SCHEMA = "birthlist";

const STORAGE_KEY = "birthlist_pw";

const gate = document.getElementById("gate");
const gateForm = document.getElementById("gate-form");
const gateError = document.getElementById("gate-error");
const passwordInput = document.getElementById("password");
const app = document.getElementById("app");
const list = document.getElementById("list");
const statusEl = document.getElementById("status");

let password = "";

async function rpc(name, args) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      apikey: SUPABASE_KEY,
      "Content-Profile": SUPABASE_SCHEMA, // schéma PostgreSQL où vivent les fonctions
    },
    body: JSON.stringify(args),
  });
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    const err = new Error(body.message || `Erreur ${res.status}`);
    err.invalidPassword = body.message === "invalid_password";
    throw err;
  }
  return res.json();
}

// N'accepte que les liens http(s) (refuse javascript:, data:, etc.).
function safeUrl(value) {
  try {
    const url = new URL(value);
    return url.protocol === "https:" || url.protocol === "http:" ? url.href : null;
  } catch {
    return null;
  }
}

function makeLink(href, content) {
  const a = document.createElement("a");
  a.href = href;
  a.target = "_blank";
  a.rel = "noopener noreferrer";
  a.append(content);
  return a;
}

function render(items) {
  list.replaceChildren();
  statusEl.textContent = items.length ? "" : "La liste est vide pour le moment.";
  for (const item of items) {
    const li = document.createElement("li");
    li.className = "item" + (item.checked ? " checked" : "");

    const name = document.createElement("span");
    name.className = "name";
    name.textContent = item.name;

    const href = safeUrl(item.link_url);
    if (href) name.replaceChildren(makeLink(href, item.name));

    // Seul l'admin peut annuler un achat (dans la base) : pas de bouton une fois acheté.
    let action;
    if (item.checked) {
      action = document.createElement("span");
      action.className = "badge-done";
      action.textContent = "✓ Acheté";
    } else {
      action = document.createElement("button");
      action.type = "button";
      action.className = "btn-buy";
      action.textContent = "Choisir";
      action.setAttribute("aria-label", `Choisir « ${item.name} »`);
      action.addEventListener("click", () => askConfirm(item));
    }

    li.append(name);
    if (item.image_url) {
      const img = document.createElement("img");
      img.src = item.image_url;
      img.alt = "";
      img.loading = "lazy";
      li.append(href ? makeLink(href, img) : img);
    }
    li.append(action);
    list.append(li);
  }
}

async function load() {
  try {
    render(await rpc("get_items", { p: password }));
  } catch (e) {
    if (e.invalidPassword) return lock();
    statusEl.textContent = "Impossible de charger la liste. Réessayez plus tard.";
  }
}

const confirmDialog = document.getElementById("confirm");
const confirmName = document.getElementById("confirm-name");
const confirmYes = document.getElementById("confirm-yes");
const confirmNo = document.getElementById("confirm-no");
let pendingItem = null;

function askConfirm(item) {
  pendingItem = item;
  confirmName.textContent = item.name;
  confirmYes.disabled = false;
  confirmDialog.showModal();
}

confirmNo.addEventListener("click", () => confirmDialog.close());
// Un clic à côté de la boîte (sur le fond) équivaut à « Non ». Échap aussi (natif).
confirmDialog.addEventListener("click", (e) => {
  if (e.target === confirmDialog) confirmDialog.close();
});
confirmDialog.addEventListener("close", () => { pendingItem = null; });

confirmYes.addEventListener("click", async () => {
  if (!pendingItem) return;
  confirmYes.disabled = true;
  try {
    await rpc("check_item", { p: password, item_id: pendingItem.id });
    statusEl.textContent = "";
  } catch (e) {
    if (e.invalidPassword) { confirmDialog.close(); return lock(); }
    statusEl.textContent = "L'article n'a pas pu être marqué comme acheté. Réessayez.";
  }
  confirmDialog.close();
  await load();
});

function unlock() {
  gate.hidden = true;
  app.hidden = false;
  load();
}

function lock() {
  sessionStorage.removeItem(STORAGE_KEY);
  password = "";
  app.hidden = true;
  gate.hidden = false;
}

gateForm.addEventListener("submit", async (e) => {
  e.preventDefault();
  const button = gateForm.querySelector("button");
  button.disabled = true;
  gateError.textContent = "";
  try {
    const ok = await rpc("verify_password", { p: passwordInput.value });
    if (ok) {
      password = passwordInput.value;
      try { sessionStorage.setItem(STORAGE_KEY, password); } catch {}
      passwordInput.value = "";
      unlock();
    } else {
      gateError.textContent = "Mot de passe incorrect.";
    }
  } catch {
    gateError.textContent = "Connexion impossible. Réessayez plus tard.";
  }
  button.disabled = false;
});

// Évite de redemander le mot de passe à chaque rechargement dans le même onglet.
try { password = sessionStorage.getItem(STORAGE_KEY) || ""; } catch {}
if (password) unlock();
