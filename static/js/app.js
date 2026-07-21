const csrf = document.querySelector('meta[name="csrf-token"]')?.content;

// Use the bundled fallback when remote catalog artwork is unavailable.
document.addEventListener('error', event => {
  const image = event.target;
  if (image instanceof HTMLImageElement && !image.dataset.fallbackApplied) {
    image.dataset.fallbackApplied = 'true';
    image.src = '/static/default.jpg';
  }
}, true);

const navButton = document.querySelector('.nav-toggle');
navButton?.addEventListener('click', () => {
  const nav = document.querySelector('.nav');
  const open = nav.classList.toggle('open');
  navButton.setAttribute('aria-expanded', String(open));
});

async function action(url, button, onSuccess) {
  const oldText = button.textContent;
  button.disabled = true;
  button.textContent = 'Working…';
  try {
    const response = await fetch(url, {method: 'POST', headers: {'X-CSRF-Token': csrf, 'Accept': 'application/json'}});
    const data = await response.json();
    if (!response.ok) throw new Error(data.message || 'Something went wrong');
    onSuccess(data);
    showToast(data.message);
  } catch (error) {
    button.textContent = oldText;
    showToast(error.message, true);
  } finally { button.disabled = false; }
}

document.querySelectorAll('.js-watchlist').forEach(button => button.addEventListener('click', () => {
  action(`/api/watchlist/${button.dataset.id}`, button, data => {
    button.textContent = data.saved ? 'Remove from My List' : '+ Add to My List';
  });
}));

document.querySelectorAll('.js-watched').forEach(button => button.addEventListener('click', () => {
  action(`/api/history/${button.dataset.id}`, button, () => { button.textContent = '✓ Watched'; });
}));

function showToast(message, error = false) {
  let stack = document.querySelector('.flash-stack');
  if (!stack) { stack = document.createElement('div'); stack.className = 'flash-stack'; document.body.append(stack); }
  const toast = document.createElement('div');
  toast.className = `flash ${error ? 'error' : 'success'}`;
  toast.textContent = message;
  stack.append(toast);
  setTimeout(() => toast.remove(), 3200);
}
