// Ces deux valeurs sont publiques par conception (la sécurité repose sur la base).
const SUPABASE_URL = "https://bwcizhvhtwkjfjadurcj.supabase.co";
const SUPABASE_KEY = "sb_publishable_KLQZ-MuQKYbV1_GUvOFk9Q_nfumGtNc";

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
    headers: { "Content-Type": "application/json", apikey: SUPABASE_KEY },
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

function render(items) {
  list.replaceChildren();
  statusEl.textContent = items.length ? "" : "La liste est vide pour le moment.";
  for (const item of items) {
    const li = document.createElement("li");
    li.className = "item" + (item.checked ? " checked" : "");

    const box = document.createElement("input");
    box.type = "checkbox";
    box.checked = item.checked;
    box.disabled = item.checked; // seul l'admin peut décocher (dans la base)
    box.setAttribute("aria-label", item.name);
    box.addEventListener("change", () => onCheck(item.id, box));

    const name = document.createElement("span");
    name.className = "name";
    name.textContent = item.name;

    li.append(box, name);
    if (item.image_url) {
      const img = document.createElement("img");
      img.src = item.image_url;
      img.alt = "";
      img.loading = "lazy";
      li.append(img);
    }
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

async function onCheck(id, box) {
  box.disabled = true;
  try {
    await rpc("check_item", { p: password, item_id: id });
  } catch (e) {
    statusEl.textContent = "La case n'a pas pu être cochée. Réessayez.";
  }
  await load();
}

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
