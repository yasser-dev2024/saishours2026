(() => {
  const header = document.getElementById('siteHeader');
  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  const updateHeader = () => header?.classList.toggle('scrolled', window.scrollY > 24);
  updateHeader();
  window.addEventListener('scroll', updateHeader, { passive: true });

  const revealItems = [...document.querySelectorAll('.reveal')];
  if (reducedMotion || !('IntersectionObserver' in window)) {
    revealItems.forEach((item) => item.classList.add('visible'));
  } else {
    const revealObserver = new IntersectionObserver((entries, observer) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target.classList.add('visible');
        observer.unobserve(entry.target);
      });
    }, { threshold: 0.14 });
    revealItems.forEach((item) => revealObserver.observe(item));
  }

  const counters = [...document.querySelectorAll('[data-counter]')];
  const runCounter = (node) => {
    const target = Number(node.dataset.counter || 0);
    const duration = 950;
    const start = performance.now();
    const tick = (time) => {
      const progress = Math.min((time - start) / duration, 1);
      const eased = 1 - Math.pow(1 - progress, 3);
      node.textContent = String(Math.round(target * eased));
      if (progress < 1) requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  };

  if (reducedMotion || !('IntersectionObserver' in window)) {
    counters.forEach((node) => { node.textContent = node.dataset.counter; });
  } else {
    const counterObserver = new IntersectionObserver((entries, observer) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        runCounter(entry.target);
        observer.unobserve(entry.target);
      });
    }, { threshold: .65 });
    counters.forEach((node) => counterObserver.observe(node));
  }

  const cards = [...document.querySelectorAll('.screen-card')];
  const dots = document.getElementById('slideDots');
  const previous = document.getElementById('prevSlide');
  const next = document.getElementById('nextSlide');
  let activeIndex = 0;
  let autoTimer;

  const normalizeIndex = (value) => (value + cards.length) % cards.length;
  const renderSlides = () => {
    cards.forEach((card, index) => {
      card.classList.remove('active', 'previous', 'next');
      if (index === activeIndex) card.classList.add('active');
      if (index === normalizeIndex(activeIndex - 1)) card.classList.add('previous');
      if (index === normalizeIndex(activeIndex + 1)) card.classList.add('next');
    });
    [...(dots?.children || [])].forEach((dot, index) => {
      dot.classList.toggle('active', index === activeIndex);
      dot.setAttribute('aria-current', index === activeIndex ? 'true' : 'false');
    });
  };

  const setSlide = (index, restart = true) => {
    activeIndex = normalizeIndex(index);
    renderSlides();
    if (restart) startAutoSlides();
  };

  const startAutoSlides = () => {
    window.clearInterval(autoTimer);
    if (!reducedMotion) autoTimer = window.setInterval(() => setSlide(activeIndex + 1, false), 5200);
  };

  cards.forEach((card, index) => {
    const dot = document.createElement('button');
    dot.type = 'button';
    dot.setAttribute('aria-label', `عرض ${card.dataset.title || `الصورة ${index + 1}`}`);
    dot.addEventListener('click', () => setSlide(index));
    dots?.appendChild(dot);
    card.addEventListener('click', () => setSlide(index));
  });
  previous?.addEventListener('click', () => setSlide(activeIndex - 1));
  next?.addEventListener('click', () => setSlide(activeIndex + 1));
  renderSlides();
  startAutoSlides();

  document.querySelectorAll('a[href^="#"]').forEach((link) => {
    link.addEventListener('click', (event) => {
      const target = document.querySelector(link.getAttribute('href'));
      if (!target) return;
      event.preventDefault();
      target.scrollIntoView({ behavior: reducedMotion ? 'auto' : 'smooth', block: 'start' });
    });
  });

  document.querySelectorAll('.download-link').forEach((link) => {
    link.addEventListener('click', () => {
      link.classList.add('download-started');
      window.setTimeout(() => link.classList.remove('download-started'), 1600);
    });
  });
})();
