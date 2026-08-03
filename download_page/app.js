(() => {
  document.documentElement.classList.add("js");
  const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const revealItems = [...document.querySelectorAll("[data-reveal]")];

  if ("IntersectionObserver" in window && !reducedMotion) {
    const revealObserver = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target.classList.add("revealed");
        revealObserver.unobserve(entry.target);
      });
    }, { threshold: 0.12, rootMargin: "0px 0px -45px" });

    revealItems.forEach((item, index) => {
      item.style.transitionDelay = `${Math.min(index % 4, 3) * 70}ms`;
      revealObserver.observe(item);
    });
  } else {
    revealItems.forEach((item) => item.classList.add("revealed"));
  }

  const progress = document.querySelector(".reading-progress");
  const heroPhoto = document.querySelector(".hero-photo");
  let scrollQueued = false;

  const updateScrollEffects = () => {
    const scrollTop = window.scrollY || document.documentElement.scrollTop;
    const scrollable = document.documentElement.scrollHeight - window.innerHeight;
    const percentage = scrollable > 0 ? Math.min(100, (scrollTop / scrollable) * 100) : 0;
    progress?.style.setProperty("--reading", `${percentage}%`);
    if (heroPhoto && !reducedMotion && window.innerWidth > 720) {
      heroPhoto.style.translate = `0 ${Math.min(scrollTop * 0.11, 72)}px`;
    }
    scrollQueued = false;
  };

  window.addEventListener("scroll", () => {
    if (scrollQueued) return;
    scrollQueued = true;
    requestAnimationFrame(updateScrollEffects);
  }, { passive: true });
  updateScrollEffects();

  const counter = document.querySelector("[data-count]");
  if (counter && !reducedMotion && "IntersectionObserver" in window) {
    const counterObserver = new IntersectionObserver(([entry]) => {
      if (!entry.isIntersecting) return;
      const target = Number(counter.dataset.count || 0);
      const startValue = Math.max(0, target - 60);
      const startedAt = performance.now();
      const animate = (now) => {
        const progressValue = Math.min(1, (now - startedAt) / 1100);
        const eased = 1 - Math.pow(1 - progressValue, 3);
        counter.textContent = `${Math.round(startValue + ((target - startValue) * eased))}°`;
        if (progressValue < 1) requestAnimationFrame(animate);
      };
      requestAnimationFrame(animate);
      counterObserver.disconnect();
    }, { threshold: 0.6 });
    counterObserver.observe(counter);
  } else if (counter) {
    counter.textContent = `${counter.dataset.count}°`;
  }

  const canTilt = !reducedMotion && window.matchMedia("(pointer: fine)").matches;
  if (canTilt) {
    document.querySelectorAll("[data-tilt]").forEach((card) => {
      card.addEventListener("pointermove", (event) => {
        const rect = card.getBoundingClientRect();
        const x = (event.clientX - rect.left) / rect.width;
        const y = (event.clientY - rect.top) / rect.height;
        const rotateY = (x - 0.5) * 7;
        const rotateX = (0.5 - y) * 7;
        card.style.transform = `perspective(900px) rotateX(${rotateX}deg) rotateY(${rotateY}deg) translateY(-4px)`;
        card.style.setProperty("--spot-x", `${x * 100}%`);
        card.style.setProperty("--spot-y", `${y * 100}%`);
      });
      card.addEventListener("pointerleave", () => {
        card.style.transform = "";
      });
    });

    const stage = document.querySelector(".screens-stage");
    const depthCards = [...document.querySelectorAll("[data-depth]")];
    stage?.addEventListener("pointermove", (event) => {
      if (window.innerWidth <= 720) return;
      const rect = stage.getBoundingClientRect();
      const x = ((event.clientX - rect.left) / rect.width - 0.5) * 2;
      const y = ((event.clientY - rect.top) / rect.height - 0.5) * 2;
      depthCards.forEach((card) => {
        const depth = Number(card.dataset.depth || 10);
        card.style.translate = `${x * depth}px ${y * depth * 0.45}px`;
      });
    });
    stage?.addEventListener("pointerleave", () => {
      depthCards.forEach((card) => { card.style.translate = "0 0"; });
    });
  }

  const download = document.querySelector(".download-button");
  download?.addEventListener("pointerdown", () => download.classList.add("is-pressed"));
  ["pointerup", "pointercancel", "pointerleave"].forEach((type) => {
    download?.addEventListener(type, () => download.classList.remove("is-pressed"));
  });
})();
