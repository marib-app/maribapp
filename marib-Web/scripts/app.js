(function () {
  let dataset = {};
  let copy = {};

  const iconLibrary = {
    dashboard: `
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <rect x="3" y="3" width="8" height="8" rx="2" stroke="currentColor" stroke-width="1.6" fill="none"></rect>
        <rect x="13" y="3" width="8" height="5" rx="2" stroke="currentColor" stroke-width="1.6" fill="none"></rect>
        <rect x="13" y="10" width="8" height="11" rx="2" stroke="currentColor" stroke-width="1.6" fill="none"></rect>
        <rect x="3" y="13" width="8" height="8" rx="2" stroke="currentColor" stroke-width="1.6" fill="none"></rect>
      </svg>
    `,
    wallet: `
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <path d="M4 7h16a2 2 0 0 1 2 2v6a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V9a2 2 0 0 1 2-2Z" stroke="currentColor" stroke-width="1.6" fill="none"></path>
        <path d="M16 12h4" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"></path>
        <path d="M4 7V5a2 2 0 0 1 2-2h9" stroke="currentColor" stroke-width="1.6" fill="none"></path>
      </svg>
    `,
    gallery: `
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <rect x="3" y="4" width="18" height="16" rx="3" stroke="currentColor" stroke-width="1.6" fill="none"></rect>
        <path d="M3 15.5l4.5-4.5a2 2 0 0 1 2.9 0L17 18" stroke="currentColor" stroke-width="1.6" fill="none"></path>
        <circle cx="16" cy="8" r="2" fill="currentColor"></circle>
      </svg>
    `,
    chat: `
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <path d="M5 5h14a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H10l-5 4v-4H5a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2Z" stroke="currentColor" stroke-width="1.6" fill="none"></path>
        <circle cx="9" cy="11" r="1" fill="currentColor"></circle>
        <circle cx="12" cy="11" r="1" fill="currentColor"></circle>
        <circle cx="15" cy="11" r="1" fill="currentColor"></circle>
      </svg>
    `,
    megaphone: `
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <path d="M4 10.5v3a2 2 0 0 0 2 2h1.2l1.4 3.5a1 1 0 0 0 1.85-.7L10 15" stroke="currentColor" stroke-width="1.6" fill="none"></path>
        <path d="M6 6.5 19 4v16l-13-2.5V6.5Z" stroke="currentColor" stroke-width="1.6" fill="none"></path>
      </svg>
    `,
    spark: `
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <path d="M12 3l2.1 5.6L20 9.5l-4.5 3.9L16.4 21 12 17.7 7.6 21l0.9-7.6L4 9.5l5.9-0.9L12 3Z" stroke="currentColor" stroke-width="1.6" fill="none"></path>
      </svg>
    `,
  };

  const state = {
    lang: document.documentElement.lang === 'en' ? 'en' : 'ar',
    serviceIndex: 0,
    badgeIndex: 0,
  };

  const refs = {};
  let resizeTimer;

  document.addEventListener('DOMContentLoaded', () => {
    cacheRefs();
    bootstrap();
  });

  async function bootstrap() {
    try {
      dataset = await fetchDataset();
      copy = dataset.copy || {};
      bindEvents();
      renderAll();
      kickOffRealtime();
      window.addEventListener('resize', () => {
        clearTimeout(resizeTimer);
        resizeTimer = setTimeout(updateServiceCarousel, 180);
      });
    } catch (error) {
      console.error('Unable to load site dataset', error);
      handleDatasetError();
    }
  }

  function cacheRefs() {
    refs.heroStats = document.getElementById('hero-stats');
    refs.features = document.querySelector('[data-component="features"]');
    refs.serviceTrack = document.getElementById('service-track');
    refs.testimonials = document.querySelector('[data-component="testimonials"]');
    refs.insightList = document.getElementById('insight-list');
    refs.timelineTrack = document.getElementById('timeline-track');
    refs.faq = document.querySelector('[data-component="faq"]');
    refs.badgeMeta = document.getElementById('badge-meta');
    refs.liveOrders = document.getElementById('live-orders');
    refs.liveSupport = document.getElementById('live-support');
    refs.langButtons = document.querySelectorAll('.lang-switch button');
    refs.nav = document.querySelector('.site-nav');
    refs.navToggle = document.querySelector('.nav-toggle');
    refs.contactForm = document.getElementById('contact-form');
    refs.formMessage = document.getElementById('form-message');
    refs.carouselControls = document.querySelectorAll('.carousel__control');
  }

  function bindEvents() {
    refs.langButtons?.forEach((button) => {
      button.addEventListener('click', () => {
        const lang = button.dataset.lang;
        if (lang && lang !== state.lang) {
          setLanguage(lang);
        }
      });
    });

    refs.navToggle?.addEventListener('click', () => {
      const isOpen = refs.nav?.dataset.state === 'open';
      refs.nav?.setAttribute('data-state', isOpen ? 'closed' : 'open');
      refs.navToggle?.setAttribute('aria-expanded', String(!isOpen));
    });

    document.querySelectorAll('.site-nav a').forEach((link) => {
      link.addEventListener('click', (event) => {
        const id = link.getAttribute('href');
        if (id?.startsWith('#')) {
          event.preventDefault();
          smoothScroll(id);
        }
        closeNav();
      });
    });

    document.querySelectorAll('[data-scroll]').forEach((button) => {
      button.addEventListener('click', (event) => {
        event.preventDefault();
        const target = button.getAttribute('data-scroll');
        if (target) {
          smoothScroll(target);
        }
      });
    });

    refs.carouselControls?.forEach((control) => {
      control.addEventListener('click', () => {
        const direction = control.dataset.direction === 'prev' ? -1 : 1;
        handleCarousel(direction);
      });
    });

    refs.contactForm?.addEventListener('submit', handleFormSubmit);
  }

  function smoothScroll(selector) {
    const target = document.querySelector(selector);
    if (target) {
      target.scrollIntoView({ behavior: 'smooth' });
    }
  }

  function closeNav() {
    if (!refs.nav) return;
    refs.nav.dataset.state = 'closed';
    refs.navToggle?.setAttribute('aria-expanded', 'false');
  }

  function setLanguage(lang) {
    state.lang = lang;
    document.documentElement.lang = lang;
    document.documentElement.dir = lang === 'ar' ? 'rtl' : 'ltr';
    refs.langButtons?.forEach((button) => {
      button.classList.toggle('is-active', button.dataset.lang === lang);
    });
    renderAll();
  }

  function renderAll() {
    renderStaticCopy();
    renderStats();
    renderFeatures();
    renderServices();
    renderTestimonials();
    renderInsights();
    renderTimeline();
    renderFaq();
    updateBadgeMeta();
    observeVisibility();
  }

  function renderStaticCopy() {
    document.querySelectorAll('[data-i18n]').forEach((element) => {
      const key = element.getAttribute('data-i18n');
      const value = resolveCopy(key);
      if (value) {
        element.textContent = value;
      }
    });

    document.querySelectorAll('[data-i18n-placeholder]').forEach((element) => {
      const key = element.getAttribute('data-i18n-placeholder');
      const value = resolveCopy(key);
      if (value && 'placeholder' in element) {
        element.setAttribute('placeholder', value);
      }
    });
  }

  function renderStats() {
    if (!refs.heroStats || !dataset.stats) return;
    refs.heroStats.innerHTML = '';
    dataset.stats.forEach((stat) => {
      const li = document.createElement('li');
      const strong = document.createElement('strong');
      strong.dataset.target = String(stat.value);
      strong.dataset.suffix = stat.suffix ?? '';
      strong.textContent = '0';
      const label = document.createElement('span');
      label.textContent = stat.label?.[state.lang] ?? '';
      li.append(strong, label);
      refs.heroStats.appendChild(li);
      animateStat(strong, stat.value);
    });
  }

  function renderFeatures() {
    if (!refs.features || !dataset.features) return;
    refs.features.innerHTML = '';
    dataset.features.forEach((feature) => {
      const card = document.createElement('article');
      card.className = 'card';

      const icon = document.createElement('div');
      icon.className = 'card__icon';
      icon.style.background = feature.accent;
      icon.innerHTML = iconLibrary[feature.icon] ?? '';

      const title = document.createElement('h3');
      title.textContent = feature.copy?.[state.lang]?.title ?? '';

      const body = document.createElement('p');
      body.className = 'card__meta';
      body.textContent = feature.copy?.[state.lang]?.body ?? '';

      card.append(icon, title, body);
      refs.features.appendChild(card);
    });
  }

  function renderServices() {
    if (!refs.serviceTrack || !dataset.services) return;
    refs.serviceTrack.innerHTML = '';
    dataset.services.forEach((service) => {
      const card = document.createElement('article');
      card.className = 'service-card';
      card.innerHTML = `
        <div class="service-card__head">
          <span class="badge">${service.badge?.[state.lang] ?? ''}</span>
          <h3>${service.title?.[state.lang] ?? ''}</h3>
        </div>
        <p>${service.body?.[state.lang] ?? ''}</p>
      `;

      const list = document.createElement('ul');
      service.points?.forEach((point) => {
        const li = document.createElement('li');
        li.textContent = point?.[state.lang] ?? '';
        list.appendChild(li);
      });

      card.appendChild(list);
      refs.serviceTrack.appendChild(card);
    });
    state.serviceIndex = 0;
    updateServiceCarousel();
  }

  function handleCarousel(direction) {
    if (!dataset.services?.length) return;
    const total = dataset.services.length;
    state.serviceIndex = (state.serviceIndex + direction + total) % total;
    updateServiceCarousel();
  }

  function updateServiceCarousel() {
    if (!refs.serviceTrack) return;
    const cards = Array.from(refs.serviceTrack.children);
    if (!cards.length) return;
    const target = cards[state.serviceIndex];
    const offset = target.offsetLeft;
    refs.serviceTrack.style.transform = `translateX(${-offset}px)`;
  }

  function renderTestimonials() {
    if (!refs.testimonials || !dataset.testimonials) return;
    refs.testimonials.innerHTML = '';
    dataset.testimonials.forEach((testimonial) => {
      const card = document.createElement('article');
      card.className = 'testimonial';

      const quote = document.createElement('p');
      quote.className = 'testimonial__quote';
      quote.textContent = testimonial.quote?.[state.lang] ?? '';

      const person = document.createElement('p');
      person.className = 'testimonial__person';
      person.textContent = testimonial.person ?? '';

      const role = document.createElement('p');
      role.className = 'testimonial__role';
      role.textContent = testimonial.role?.[state.lang] ?? '';

      card.append(quote, person, role);
      refs.testimonials.appendChild(card);
    });
  }

  function renderInsights() {
    if (!refs.insightList || !dataset.insights) return;
    refs.insightList.innerHTML = '';
    dataset.insights.forEach((item) => {
      const li = document.createElement('li');
      const strong = document.createElement('strong');
      strong.textContent = `${formatNumber(item.value)}${item.suffix ?? ''}`;
      const label = document.createElement('p');
      label.textContent = item.label?.[state.lang] ?? '';
      const small = document.createElement('small');
      small.textContent = `${item.change ?? ''} · ${item.period?.[state.lang] ?? ''}`;
      li.append(strong, label, small);
      refs.insightList.appendChild(li);
    });
  }

  function renderTimeline() {
    if (!refs.timelineTrack || !dataset.timeline) return;
    refs.timelineTrack.innerHTML = '';
    dataset.timeline.forEach((step, index) => {
      const row = document.createElement('div');
      row.className = 'timeline__item';
      const badge = document.createElement('div');
      badge.className = 'timeline__step';
      badge.textContent = index + 1;
      const content = document.createElement('div');
      content.className = 'timeline__content';
      const title = document.createElement('h4');
      title.textContent = step.title?.[state.lang] ?? '';
      const body = document.createElement('p');
      body.textContent = step.body?.[state.lang] ?? '';
      content.append(title, body);
      row.append(badge, content);
      refs.timelineTrack.appendChild(row);
    });
  }

  function renderFaq() {
    if (!refs.faq || !dataset.faq) return;
    refs.faq.innerHTML = '';
    dataset.faq.forEach((item) => {
      const article = document.createElement('article');
      article.className = 'faq__item';
      const question = document.createElement('h4');
      question.className = 'faq__question';
      question.textContent = item.question?.[state.lang] ?? '';
      const answer = document.createElement('p');
      answer.className = 'faq__answer';
      answer.textContent = item.answer?.[state.lang] ?? '';
      article.append(question, answer);
      refs.faq.appendChild(article);
    });
  }

  function updateBadgeMeta() {
    if (!refs.badgeMeta || !dataset.heroBadges) return;
    const entries = dataset.heroBadges[state.lang];
    if (!entries?.length) return;
    const message = entries[state.badgeIndex % entries.length];
    refs.badgeMeta.textContent = message;
  }

  function kickOffRealtime() {
    const baseOrders = dataset.liveMetrics?.orders ?? 0;
    const baseSupport = dataset.liveMetrics?.support ?? 0;

    pulseLiveTiles(baseOrders, baseSupport);
    updateBadgeMeta();

    setInterval(() => {
      pulseLiveTiles(baseOrders, baseSupport);
      const badgeSet = dataset.heroBadges?.[state.lang] ?? [];
      state.badgeIndex =
        badgeSet.length === 0
          ? 0
          : (state.badgeIndex + 1) % badgeSet.length;
      updateBadgeMeta();
    }, 5000);
  }

  function pulseLiveTiles(baseOrders, baseSupport) {
    if (refs.liveOrders) {
      animateStat(refs.liveOrders, jitter(baseOrders, 0.18));
    }
    if (refs.liveSupport) {
      animateStat(refs.liveSupport, jitter(baseSupport, 0.25));
    }
  }

  function animateStat(element, target) {
    const suffix = element.dataset.suffix ?? '';
    const startValue = Number(element.dataset.value) || 0;
    const duration = 1000;
    const start = performance.now();

    function frame(now) {
      const progress = Math.min((now - start) / duration, 1);
      const current = Math.floor(startValue + (target - startValue) * progress);
      element.dataset.value = String(current);
      element.textContent = `${formatNumber(current)}${suffix}`;
      if (progress < 1) {
        requestAnimationFrame(frame);
      }
    }

    requestAnimationFrame(frame);
  }

  function formatNumber(value) {
    const locale = state.lang === 'ar' ? 'ar-SA' : 'en-US';
    return new Intl.NumberFormat(locale, { maximumFractionDigits: 0 }).format(
      Math.round(value),
    );
  }

  function jitter(value, ratio = 0.15) {
    if (!Number.isFinite(value) || value <= 0) {
      return randomBetween(1, 9);
    }

    const delta = Math.max(2, Math.round(value * ratio));
    const min = Math.max(0, Math.round(value - delta));
    const max = Math.round(value + delta);

    return randomBetween(min, max);
  }

  function randomBetween(min, max) {
    return Math.floor(Math.random() * (max - min + 1)) + min;
  }

  function handleFormSubmit(event) {
    event.preventDefault();
    if (!refs.contactForm) return;

    if (!refs.contactForm.checkValidity()) {
      renderFormMessage('form.error', '#ffbb33');
      refs.contactForm.reportValidity();
      return;
    }

    const formData = new FormData(refs.contactForm);
    const payload = Object.fromEntries(formData.entries());
    payload.language = state.lang;
    payload.timestamp = new Date().toISOString();

    try {
      const key = 'maribWebLeads';
      const current = JSON.parse(localStorage.getItem(key) || '[]');
      current.push(payload);
      localStorage.setItem(key, JSON.stringify(current));
      refs.contactForm.reset();
      renderFormMessage('form.success', '#32c48d');
    } catch (error) {
      console.error('Unable to persist lead', error);
      renderFormMessage('form.error', '#ffbb33');
    }
  }

  function renderFormMessage(key, color) {
    if (!refs.formMessage) return;
    refs.formMessage.textContent = resolveCopy(key) ?? '';
    refs.formMessage.style.color = color;
  }

  function resolveCopy(path) {
    if (!path) return '';
    return path
      .split('.')
      .reduce((acc, segment) => acc?.[segment], copy)?.[state.lang];
  }

  function observeVisibility() {
    const elements = document.querySelectorAll(
      '.card, .testimonial, .timeline__item, .faq__item',
    );
    if (!elements.length) return;
    const observer = new IntersectionObserver(
      (entries, obs) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add('is-visible');
            obs.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.2 },
    );

    elements.forEach((element) => observer.observe(element));
  }

  async function fetchDataset() {
    const params = new URLSearchParams(window.location.search);
    const overrideParam = params.get('api') ?? params.get('apiBase');

    let endpoint =
      overrideParam ||
      document.documentElement.dataset.apiEndpoint ||
      window.MARIB_API_ENDPOINT ||
      '/api/web/experience';

    endpoint = normalizeEndpoint(endpoint);

    const response = await fetch(endpoint, {
      headers: { Accept: 'application/json' },
    });

    if (!response.ok) {
      throw new Error(`Request failed with status ${response.status}`);
    }

    return response.json();
  }

  function handleDatasetError() {
    const fallbackMessage =
      state.lang === 'en'
        ? 'Unable to load platform data. Please refresh later.'
        : 'تعذر تحميل بيانات المنصة، يرجى المحاولة لاحقاً.';

    if (refs.heroStats) {
      refs.heroStats.innerHTML = '';
      const li = document.createElement('li');
      li.className = 'data-error';
      li.textContent = fallbackMessage;
      refs.heroStats.appendChild(li);
    }

    if (refs.features) {
      refs.features.innerHTML = '';
      const div = document.createElement('div');
      div.className = 'data-error';
      div.textContent = fallbackMessage;
      refs.features.appendChild(div);
    }
  }

  function normalizeEndpoint(endpoint) {
    if (/^https?:\/\//i.test(endpoint)) {
      return endpoint;
    }

    try {
      return new URL(endpoint, window.location.origin).toString();
    } catch (_) {
      return `${window.location.origin}/api/web/experience`;
    }
  }
})();
