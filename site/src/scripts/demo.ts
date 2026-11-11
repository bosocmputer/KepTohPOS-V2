// Offline toggle demo. Vanilla; GSAP is imported lazily only for the sync animation.
const AMOUNTS = [1629, 842, 2310, 459, 1175, 1980];
const TABLES = [7, 3, 12, 5, 9, 2];
const MAX_ITEMS = 6;

export function initDemo(reduced: boolean): void {
  const root = document.getElementById('offline-demo');
  const toggle = document.getElementById('net-toggle') as HTMLButtonElement | null;
  const billBtn = document.getElementById('bill-btn') as HTMLButtonElement | null;
  const queue = document.getElementById('queue');
  const empty = document.getElementById('queue-empty');
  const live = document.getElementById('demo-live');
  const cloud = document.getElementById('cloud');
  const cloudIco = cloud?.querySelector<HTMLElement>('.cloud__ico');
  const cloudCount = document.getElementById('cloud-count');
  const stateLabel = document.getElementById('net-state');
  if (!root || !toggle || !billBtn || !queue || !live || !cloudCount || !stateLabel) return;

  const d = root.dataset;
  const fmt = (s: string, v: Record<string, string | number>) => s.replace(/\{(\w+)\}/g, (_, k: string) => String(v[k] ?? ''));
  const money = new Intl.NumberFormat(document.documentElement.lang, { style: 'currency', currency: 'THB', maximumFractionDigits: 0 });

  let offline = false;
  let n = 100;
  let synced = 0;
  let run = 0;
  let cancel: (() => void) | null = null;
  const say = (m: string) => { live.textContent = m; };
  const pendingItems = () => Array.from(queue.querySelectorAll<HTMLElement>('.bill:not(.is-synced)'));

  function addBill(): void {
    n += 1;
    const i = (n - 101) % AMOUNTS.length;
    const li = document.createElement('li');
    li.className = 'bill';
    li.innerHTML = '<span></span><b></b><span class="bill__badge"></span>';
    const [label, amt, badge] = Array.from(li.children) as HTMLElement[];
    label.textContent = fmt(d.bill ?? '', { n, t: TABLES[i] });
    amt.textContent = money.format(AMOUNTS[i]);
    badge.textContent = offline ? (d.pending ?? '') : (d.synced ?? '');
    if (!offline) li.classList.add('is-synced');
    empty?.remove();
    queue!.prepend(li);
    while (queue!.children.length > MAX_ITEMS) queue!.lastElementChild?.remove();
    if (offline) say(fmt(d.msgAdded ?? '', { n, count: pendingItems().length }));
    else { synced += 1; cloudCount!.textContent = String(synced); say(d.msgOnline ?? ''); }
  }

  function markSynced(li: HTMLElement): void {
    li.classList.add('is-synced');
    const b = li.querySelector('.bill__badge');
    if (b) b.textContent = d.synced ?? '';
    synced += 1;
    cloudCount!.textContent = String(synced);
  }

  async function syncAll(): Promise<void> {
    const items = pendingItems().reverse(); // oldest first
    if (!items.length) { say(d.msgOnline ?? ''); return; }
    say(fmt(d.msgSyncing ?? '', { count: items.length }));
    const my = ++run;
    if (reduced || !cloudIco) {
      items.forEach(markSynced);
      say(d.msgDone ?? '');
      return;
    }
    const { gsap } = await import('gsap');
    if (my !== run) return;
    const packets: HTMLElement[] = [];
    const tl = gsap.timeline({ onComplete: () => { if (my === run) say(d.msgDone ?? ''); } });
    cancel = () => { tl.kill(); packets.forEach((p) => p.remove()); };
    items.forEach((li, idx) => {
      const p = document.createElement('span');
      p.className = 'packet';
      document.body.appendChild(p);
      packets.push(p);
      tl.add(() => {
        const a = li.getBoundingClientRect();
        const c = cloudIco.getBoundingClientRect();
        gsap.set(p, { x: a.right - 24, y: a.top + a.height / 2 - 6, opacity: 1, scale: 1 });
        gsap.to(p, {
          x: c.left + c.width / 2 - 6, y: c.top + c.height / 2 - 6, scale: 0.4, duration: 0.6, ease: 'power2.in',
          onComplete: () => {
            p.remove();
            if (my !== run) return;
            markSynced(li);
            gsap.fromTo(cloudIco, { scale: 1.2 }, { scale: 1, duration: 0.35, ease: 'back.out(3)' });
          },
        });
      }, idx * 0.45);
    });
  }

  toggle.addEventListener('click', () => {
    offline = !offline;
    toggle.setAttribute('aria-pressed', String(offline));
    root.dataset.state = offline ? 'offline' : 'online';
    stateLabel.textContent = (offline ? d.labelOffline : d.labelOnline) ?? '';
    cancel?.(); cancel = null; run += 1;
    if (offline) say(d.msgOffline ?? '');
    else void syncAll();
  });
  billBtn.addEventListener('click', addBill);
}
