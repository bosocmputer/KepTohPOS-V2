// GSAP + ScrollTrigger reveals and the receipt "print" effect. Loaded lazily.
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';

export function initMotion(): void {
  gsap.registerPlugin(ScrollTrigger);
  const below = (el: Element) => el.getBoundingClientRect().top > innerHeight * 0.95;

  document.querySelectorAll<HTMLElement>('[data-reveal]').forEach((el) => {
    if (!below(el)) return;
    gsap.from(el, { autoAlpha: 0, y: 28, duration: 0.8, ease: 'power2.out', clearProps: 'all', scrollTrigger: { trigger: el, start: 'top 88%', once: true } });
  });
  document.querySelectorAll<HTMLElement>('[data-stagger]').forEach((el) => {
    if (!below(el)) return;
    gsap.from(el.children, { autoAlpha: 0, y: 28, duration: 0.7, ease: 'power2.out', stagger: 0.1, clearProps: 'all', scrollTrigger: { trigger: el, start: 'top 85%', once: true } });
  });

  const receipt = document.getElementById('receipt');
  if (receipt) {
    const nums = receipt.querySelectorAll<HTMLElement>('[data-count]');
    const state = { p: 0 };
    const fmt = (v: number) => v.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    const tl = gsap.timeline({ paused: true });
    tl.fromTo(receipt, { yPercent: -102 }, { yPercent: 0, duration: 1.8, ease: 'power1.inOut' })
      .to(state, {
        p: 1, duration: 1.4, ease: 'power2.out',
        onUpdate: () => nums.forEach((n) => { n.textContent = fmt(Number(n.dataset.count) * state.p); }),
        onComplete: () => nums.forEach((n) => { n.textContent = fmt(Number(n.dataset.count)); }),
      }, 0.6);
    nums.forEach((n) => { n.textContent = fmt(0); });
    gsap.set(receipt, { yPercent: -102 });
    ScrollTrigger.create({ trigger: receipt, start: 'top 80%', once: true, onEnter: () => tl.play() });
  }
}
