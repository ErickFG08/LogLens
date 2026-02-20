// ── Theme toggle ────────────────────────────────────────────
(function initTheme() {
  const STORAGE_KEY = 'loglens-theme';

  // Apply saved theme immediately (before paint)
  const saved = localStorage.getItem(STORAGE_KEY);
  if (saved === 'dark') {
    document.documentElement.setAttribute('data-theme', 'dark');
  }

  document.addEventListener('DOMContentLoaded', () => {
    const btn = document.getElementById('theme-toggle');
    if (!btn) return;

    function updateIcon() {
      const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
      const iconEl = btn.querySelector('.theme-icon');
      if (iconEl) {
        iconEl.innerHTML = isDark ? '☀️' : '🌙';
        iconEl.style.transform = isDark ? 'rotate(360deg)' : 'rotate(0deg)';
      }
    }

    updateIcon();

    btn.addEventListener('click', () => {
      const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
      if (isDark) {
        document.documentElement.removeAttribute('data-theme');
        localStorage.setItem(STORAGE_KEY, 'light');
      } else {
        document.documentElement.setAttribute('data-theme', 'dark');
        localStorage.setItem(STORAGE_KEY, 'dark');
      }
      updateIcon();
    });
  });
}());
