(() => {
  'use strict';

  // ---- Theme toggle ----
  const root = document.documentElement;
  const themeToggle = document.getElementById('themeToggle');
  const storedTheme = localStorage.getItem('theme');
  const prefersLight = window.matchMedia('(prefers-color-scheme: light)').matches;

  function applyTheme(theme) {
    if (theme === 'light') root.setAttribute('data-theme', 'light');
    else root.removeAttribute('data-theme');
  }

  applyTheme(storedTheme || (prefersLight ? 'light' : 'dark'));

  themeToggle.addEventListener('click', () => {
    const isLight = root.getAttribute('data-theme') === 'light';
    const next = isLight ? 'dark' : 'light';
    applyTheme(next);
    localStorage.setItem('theme', next);
  });

  // ---- Header scroll state ----
  const header = document.getElementById('siteHeader');
  const onScroll = () => {
    header.classList.toggle('scrolled', window.scrollY > 10);
  };
  onScroll();
  window.addEventListener('scroll', onScroll, { passive: true });

  // ---- Mobile nav ----
  const burger = document.getElementById('burger');
  const navLinks = document.getElementById('navLinks');
  burger.addEventListener('click', () => {
    burger.classList.toggle('open');
    navLinks.classList.toggle('open');
  });
  navLinks.querySelectorAll('a').forEach(a => {
    a.addEventListener('click', () => {
      burger.classList.remove('open');
      navLinks.classList.remove('open');
    });
  });

  // ---- Cursor glow ----
  const glow = document.getElementById('cursorGlow');
  if (window.matchMedia('(pointer: fine)').matches) {
    window.addEventListener('mousemove', (e) => {
      glow.style.transform = `translate(${e.clientX}px, ${e.clientY}px) translate(-50%, -50%)`;
    });
  }

  // ---- Scroll reveal ----
  const revealEls = document.querySelectorAll('.reveal');
  const revealObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('visible');
        revealObserver.unobserve(entry.target);
      }
    });
  }, { threshold: 0.15 });
  revealEls.forEach(el => revealObserver.observe(el));

  // ---- Counters ----
  const counters = document.querySelectorAll('.stat-num');
  const counterObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (!entry.isIntersecting) return;
      const el = entry.target;
      const target = parseInt(el.dataset.count, 10);
      const suffix = el.dataset.suffix || '';
      const duration = 1200;
      const start = performance.now();
      function tick(now) {
        const progress = Math.min((now - start) / duration, 1);
        const eased = 1 - Math.pow(1 - progress, 3);
        el.textContent = Math.round(eased * target) + suffix;
        if (progress < 1) requestAnimationFrame(tick);
      }
      requestAnimationFrame(tick);
      counterObserver.unobserve(el);
    });
  }, { threshold: 0.5 });
  counters.forEach(el => counterObserver.observe(el));

  // ---- Skill bars ----
  const skillBars = document.querySelectorAll('.skill-bar');
  const skillObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (!entry.isIntersecting) return;
      const bar = entry.target;
      const level = bar.dataset.level;
      const fill = bar.querySelector('.skill-fill');
      requestAnimationFrame(() => { fill.style.width = level + '%'; });
      skillObserver.unobserve(bar);
    });
  }, { threshold: 0.3 });
  skillBars.forEach(el => skillObserver.observe(el));

  // ---- Contact form validation ----
  const form = document.getElementById('contactForm');
  const status = document.getElementById('formStatus');
  const submitText = document.getElementById('submitText');

  const validators = {
    name: (v) => v.trim().length >= 2 ? '' : 'Введите имя (минимум 2 символа)',
    email: (v) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v.trim()) ? '' : 'Введите корректный email',
    message: (v) => v.trim().length >= 10 ? '' : 'Сообщение должно быть не короче 10 символов',
  };

  function validateField(id) {
    const input = document.getElementById(id);
    const errorEl = document.getElementById(id + 'Error');
    const msg = validators[id](input.value);
    input.closest('.field').classList.toggle('invalid', !!msg);
    errorEl.textContent = msg;
    return !msg;
  }

  ['name', 'email', 'message'].forEach(id => {
    const input = document.getElementById(id);
    input.addEventListener('blur', () => validateField(id));
    input.addEventListener('input', () => {
      if (input.closest('.field').classList.contains('invalid')) validateField(id);
    });
  });

  form.addEventListener('submit', (e) => {
    e.preventDefault();
    const validName = validateField('name');
    const validEmail = validateField('email');
    const validMessage = validateField('message');

    if (!validName || !validEmail || !validMessage) {
      status.textContent = 'Пожалуйста, исправьте отмеченные поля.';
      status.className = 'form-status';
      return;
    }

    submitText.textContent = 'Отправка...';
    status.textContent = '';
    status.className = 'form-status';

    setTimeout(() => {
      submitText.textContent = 'Отправить сообщение';
      status.textContent = 'Спасибо! Сообщение отправлено, я скоро отвечу.';
      status.className = 'form-status success';
      form.reset();
      document.querySelectorAll('.field').forEach(f => f.classList.remove('invalid'));
    }, 900);
  });

  // ---- Footer year & to-top ----
  document.getElementById('year').textContent = new Date().getFullYear();
  const toTop = document.getElementById('toTop');
  toTop.addEventListener('click', () => window.scrollTo({ top: 0, behavior: 'smooth' }));
})();
