// Inner Sun landing page: clips play while on screen, the depth gauge follows the scroll, and the dossier's
// redactions lift once it has been read. The page works without this script except the motion.
(function () {
  'use strict';
  const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const conn = navigator.connection;
  // Only real data saver or a very slow link skips autoplay (a "3g" label is common on fine connections).
  const saveData = !!(conn && (conn.saveData || /(^|-)2g$/.test(conn.effectiveType || '')));

  const play = (v) => {
    if (saveData || reduced) {
      v.controls = true;
      return;
    }
    if (v.preload === 'none') v.preload = 'auto';
    v.play().catch(() => (v.controls = true));
  };

  // hero loop: stop it on reduced motion or data saver, show controls instead
  const hero = document.getElementById('hero-video');
  if (hero && (saveData || reduced)) {
    hero.removeAttribute('autoplay');
    hero.pause();
    hero.controls = true;
  }

  // clips that play while they are on screen
  const inview = [...document.querySelectorAll('video[data-inview]')];
  if ('IntersectionObserver' in window) {
    const io = new IntersectionObserver(
      (es) => {
        for (const e of es) {
          if (e.isIntersecting) play(e.target);
          else e.target.pause();
        }
      },
      { threshold: 0.4 },
    );
    inview.forEach((v) => io.observe(v));
    if (hero && !saveData && !reduced) io.observe(hero);
  } else {
    inview.forEach((v) => (v.controls = true));
  }

  // the depth gauge: 0 m at the surface, 214 m at the gate (the making-of section)
  const fill = document.getElementById('gauge-fill');
  const value = document.getElementById('gauge-value');
  const MAX_M = 214;
  let ticking = false;
  const gauge = () => {
    ticking = false;
    const h = document.documentElement.scrollHeight - window.innerHeight;
    const p = h > 0 ? Math.min(1, Math.max(0, window.scrollY / h)) : 0;
    fill.style.height = `${p * 100}%`;
    value.textContent = `${Math.round(p * MAX_M)} m`;
  };
  window.addEventListener('scroll', () => {
    if (!ticking) {
      ticking = true;
      requestAnimationFrame(gauge);
    }
  }, { passive: true });
  gauge();

  // the redactions lift a moment after the dossier is on screen (the codex, in miniature)
  const bars = [...document.querySelectorAll('.redact')];
  const dossier = document.querySelector('.dossier');
  if (dossier && bars.length && 'IntersectionObserver' in window) {
    const lift = new IntersectionObserver((es) => {
      if (es.some((e) => e.isIntersecting)) {
        bars.forEach((b, i) => setTimeout(() => b.classList.add('lifted'), reduced ? 0 : 1600 + i * 900));
        lift.disconnect();
      }
    }, { threshold: 0.6 });
    lift.observe(dossier);
  } else {
    bars.forEach((b) => b.classList.add('lifted'));
  }
})();
