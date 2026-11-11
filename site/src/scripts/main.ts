// Entry point: tiny, framework-free. Heavy libs (gsap, lottie) are dynamic imports.
import { initDemo } from './demo';

const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;

// Run fn once on the first real interaction (keeps heavy libs out of initial load).
function onFirstInteraction(fn: () => void): void {
  const events = ['pointerdown', 'keydown', 'touchstart', 'scroll', 'wheel'];
  const run = () => {
    events.forEach((e) => removeEventListener(e, run));
    fn();
  };
  events.forEach((e) => addEventListener(e, run, { once: true, passive: true }));
}

// Scroll progress (CSS variable) + walker position.
const walker = document.getElementById('walker');
const bar = document.getElementById('progress-bar');
let ticking = false;
function updateProgress(): void {
  ticking = false;
  const max = document.documentElement.scrollHeight - innerHeight;
  const p = max > 0 ? Math.min(1, Math.max(0, scrollY / max)) : 0;
  if (bar) bar.style.setProperty('--p', String(p));
  if (bar && walker) {
    const w = bar.parentElement?.clientWidth ?? 0;
    walker.style.setProperty("--wx", `${Math.max(0, p * (w - walker.offsetWidth))}px`);
  }
}
if (bar) {
  addEventListener('scroll', () => { if (!ticking) { ticking = true; requestAnimationFrame(updateProgress); } }, { passive: true });
  addEventListener('resize', updateProgress, { passive: true });
  updateProgress();
}

// Sticky mobile CTA after the hero has scrolled past.
const hero = document.getElementById('hero');
const sticky = document.getElementById('sticky-cta');
if (hero && sticky && 'IntersectionObserver' in window) {
  new IntersectionObserver(([entry]) => {
    const show = !entry.isIntersecting && entry.boundingClientRect.top < 0;
    sticky.classList.toggle('is-visible', show);
    sticky.setAttribute('aria-hidden', String(!show));
    sticky.querySelector('a')?.setAttribute('tabindex', show ? '0' : '-1');
    document.body.classList.toggle('has-bar', show);
  }).observe(hero);
}

initDemo(reduced);

onFirstInteraction(() => {
  if (reduced) return;
  import('./motion').then((m) => m.initMotion());
  if (walker) {
    import('lottie-web/build/player/lottie_light').then(({ default: lottie }) => {
      lottie.loadAnimation({ container: walker, renderer: 'svg', loop: true, autoplay: true, path: '/Walking_Orange.json' });
      walker.classList.add('is-on');
    });
  }
});
