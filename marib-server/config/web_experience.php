<?php

declare(strict_types=1);

$json = <<<'JSON'
{
  "copy": {
    "brand": {
      "name": { "ar": "مأرب", "en": "Marib" },
      "tagline": {
        "ar": "حياة أسهل لكل متجر",
        "en": "Unified journeys for every merchant"
      }
    },
    "nav": {
      "home": { "ar": "الرئيسية", "en": "Home" },
      "services": { "ar": "الخدمات", "en": "Services" },
      "solutions": { "ar": "الحلول", "en": "Solutions" },
      "stories": { "ar": "قصص النجاح", "en": "Stories" },
      "contact": { "ar": "تواصل معنا", "en": "Contact" },
      "partners": { "ar": "مركز الشركاء", "en": "Partner Hub" },
      "login": { "ar": "تسجيل الدخول", "en": "Merchant Login" }
    },
    "hero": {
      "eyebrow": {
        "ar": "منصة مأرب الموحدة",
        "en": "Marib Connected Platform"
      },
      "title": {
        "ar": "تجربة رقمية كاملة تربط المتاجر بالمجتمع في لحظة واحدة",
        "en": "An end-to-end digital journey that connects stores and communities instantly"
      },
      "subtitle": {
        "ar": "من الاكتشاف إلى الإدارة إلى خدمة ما بعد البيع، يقدم مأرب تطبيقاً عربي الهوية لكل متجر يبحث عن نمو واستدامة.",
        "en": "From discovery to daily operations and after-sales care, Marib gives merchants an Arabic-first experience built for growth."
      },
      "btnPrimary": { "ar": "حمّل التطبيق الآن", "en": "Download the app" },
      "btnSecondary": { "ar": "استكشف المزايا", "en": "Explore features" },
      "badge": { "ar": "خدمات المدن الذكية", "en": "Smart city services" },
      "floatingTitle": { "ar": "مؤشرات حية", "en": "Live indicators" },
      "floatingCaption": { "ar": "طلبات نشطة", "en": "Active orders" },
      "floatingCaption2": { "ar": "جلسات دعم", "en": "Support sessions" }
    },
    "solutions": {
      "eyebrow": { "ar": "حلول ذكية", "en": "Smart Solutions" },
      "title": {
        "ar": "كل ما تحتاجه لإدارة متجرك في منصة واحدة",
        "en": "Everything your store needs in one platform"
      },
      "subtitle": {
        "ar": "واجهات تشبه التطبيق، مع تجربة ويب خفيفة وسلسة ومهيأة للعرض العربي.",
        "en": "App-like panels in a lightweight, RTL-friendly web experience."
      }
    },
    "services": {
      "eyebrow": { "ar": "قيمة مضافة", "en": "Value Layers" },
      "title": {
        "ar": "خدمات ميدانية وسحابية تدعم تشغيلك اليومي",
        "en": "Field and cloud services powering your daily operations"
      },
      "subtitle": {
        "ar": "تعمل مأرب مع شركاء محليين لتوفير سلسلة خدمات متكاملة من التحقق وحتى التحليلات.",
        "en": "Marib partners locally to deliver an integrated chain from verification to analytics."
      }
    },
    "stories": {
      "eyebrow": { "ar": "قصص حقيقية", "en": "Voices" },
      "title": {
        "ar": "أصوات من المجتمع التجاري",
        "en": "Real voices from the merchant community"
      },
      "subtitle": {
        "ar": "اقتباسات قصيرة ذات مصداقية توضح كيف غيّر مأرب طريقة عمل المتاجر.",
        "en": "Short, credible testimonials on how Marib reshapes operations."
      }
    },
    "insights": {
      "eyebrow": { "ar": "رؤى مجتمعية", "en": "Community Insights" },
      "title": {
        "ar": "نبض المنصة يعرض تفاعلات ومبيعات حية",
        "en": "Platform pulse shows live commerce interactions"
      }
    },
    "timeline": {
      "title": {
        "ar": "رحلة التاجر مع مأرب",
        "en": "A merchant journey with Marib"
      }
    },
    "faq": {
      "eyebrow": { "ar": "أجوبة سريعة", "en": "Quick answers" },
      "title": { "ar": "أسئلة نسمعها يومياً", "en": "Questions we hear often" },
      "subtitle": {
        "ar": "دعم التطبيق نفسه متاح هنا عبر نفس الهوية والتجربة.",
        "en": "App-grade support is mirrored on the web with the same identity."
      }
    },
    "cta": {
      "eyebrow": { "ar": "تواصل مباشر", "en": "Talk to us" },
      "title": {
        "ar": "لِنَصنع تجربة تطبيقك الويب بنفس الهوية",
        "en": "Let’s bring your app identity to the web"
      },
      "subtitle": {
        "ar": "أرسل لنا بيانات بسيطة وسيعاودك فريق نجاح الشركاء خلال 24 ساعة.",
        "en": "Share a few details and the partner success team calls back within 24h."
      },
      "mail": { "ar": "دعم فني", "en": "Technical support" },
      "phone": { "ar": "خط المبيعات", "en": "Sales line" }
    },
    "form": {
      "nameLabel": { "ar": "اسم المتجر", "en": "Store name" },
      "namePlaceholder": { "ar": "متجر النخبة", "en": "Elite Store" },
      "personLabel": { "ar": "الشخص المسؤول", "en": "Contact person" },
      "personPlaceholder": { "ar": "ليان السالمي", "en": "Lian Al-Salmi" },
      "channelLabel": { "ar": "قناة التواصل المفضلة", "en": "Preferred channel" },
      "channelPlaceholder": { "ar": "770 123 456", "en": "+967 770 123 456" },
      "needLabel": { "ar": "ما الذي تحتاجه؟", "en": "What do you need?" },
      "needPlaceholder": { "ar": "أرغب في ربط فروعنا بخدمة الاكتشاف.", "en": "I want our branches discoverable across the city." },
      "cta": { "ar": "أرسل الطلب", "en": "Request a call" },
      "success": { "ar": "تم استلام الطلب، سنتواصل معك خلال يوم عمل واحد.", "en": "Request captured. Expect a callback within one business day." },
      "error": { "ar": "يرجى تعبئة الحقول المطلوبة قبل الإرسال.", "en": "Please fill in the required fields before sending." }
    },
    "footer": {
      "company": { "ar": "منصة مأرب - حلول التجارة والخدمات الذكية", "en": "Marib Platform · Commerce & smart services" },
      "rights": { "ar": "جميع الحقوق محفوظة © 2025", "en": "All rights reserved © 2025" },
      "mainApp": { "ar": "تطبيق مأرب", "en": "Marib app" },
      "privacy": { "ar": "الخصوصية", "en": "Privacy" },
      "terms": { "ar": "الشروط", "en": "Terms" }
    }
  },
  "stats": [
    { "id": "listings", "value": 68000, "suffix": "+", "label": { "ar": "إعلان فعال", "en": "Active listings" } },
    { "id": "stores", "value": 1200, "suffix": "+", "label": { "ar": "متجر موثّق", "en": "Verified stores" } },
    { "id": "cities", "value": 34, "suffix": "", "label": { "ar": "مدينة مخدومة", "en": "Cities served" } },
    { "id": "support", "value": 240, "suffix": "+", "label": { "ar": "جلسة دعم يومية", "en": "Daily support sessions" } }
  ],
  "features": [
    {
      "id": "control",
      "icon": "dashboard",
      "accent": "linear-gradient(135deg,#4fa5ba,#a8d7e6)",
      "copy": {
        "ar": { "title": "لوحة تحكم موحدة", "body": "راقب الطلبات، المخزون، والفروع عبر واجهة تحاكي التطبيق وتدعم اللمس." },
        "en": { "title": "Unified control center", "body": "Monitor orders, stock, and branches in an app-like interface with touch gestures." }
      }
    },
    {
      "id": "wallet",
      "icon": "wallet",
      "accent": "linear-gradient(135deg,#eb5924,#fa6e53)",
      "copy": {
        "ar": { "title": "دفعات آمنة وسريعة", "body": "تحويلات لحظية، تتبع عمولات، ودفاتر صادرة تشبه تجربة التطبيق." },
        "en": { "title": "Secure fast payouts", "body": "Instant transfers, fee tracking, and outbox records mirroring the app experience." }
      }
    },
    {
      "id": "media",
      "icon": "gallery",
      "accent": "linear-gradient(135deg,#5a5ef8,#9b8cfc)",
      "copy": {
        "ar": { "title": "مكتبة وسائط ذكية", "body": "إدارة صور، فيديوهات، ونماذج 360 درجة بنفس جودة التطبيق." },
        "en": { "title": "Smart media library", "body": "Manage photos, video, and 360 assets with the same fidelity as the mobile app." }
      }
    },
    {
      "id": "chat",
      "icon": "chat",
      "accent": "linear-gradient(135deg,#11172a,#4fa5ba)",
      "copy": {
        "ar": { "title": "دردشة ودعم لحظي", "body": "قنوات رسائل موحدة مع الترجمة الفورية وتنبيهات الانتباه." },
        "en": { "title": "Instant chat & care", "body": "Unified messaging with inline translation and escalation nudges." }
      }
    },
    {
      "id": "campaigns",
      "icon": "megaphone",
      "accent": "linear-gradient(135deg,#ff8a5c,#ffc15e)",
      "copy": {
        "ar": { "title": "حملات ترويجية جاهزة", "body": "قوالب مرئية تراعي العربية، مع تتبع مباشر لاستخدام القسائم." },
        "en": { "title": "Ready promo campaigns", "body": "RTL-friendly creative templates with real-time coupon tracking." }
      }
    },
    {
      "id": "analytics",
      "icon": "spark",
      "accent": "linear-gradient(135deg,#5dd39e,#348f50)",
      "copy": {
        "ar": { "title": "تحليلات تنبؤية", "body": "نموذج طلب متقدم يعرض الطلب المتوقع على مستوى الحي." },
        "en": { "title": "Predictive analytics", "body": "Advanced demand modeling down to the neighborhood level." }
      }
    }
  ],
  "services": [
    {
      "id": "onboarding",
      "badge": { "ar": "خلال أسبوع", "en": "Under 1 week" },
      "title": { "ar": "تشغيل واستيراد البيانات", "en": "Onboarding & data import" },
      "body": { "ar": "نضبط حساباتك، نصمم الأصول، ونربط الفروع بنفس سياسات التطبيق.", "en": "We configure accounts, design assets, and link branches to mirror app policies." },
      "points": [
        { "ar": "استيراد منتجات من CSV أو المتاجر السحابية", "en": "Import catalogs from CSV or cloud stores" },
        { "ar": "تدقيق الهوية والوثائق إلكترونياً", "en": "Digital KYC & documentation audit" },
        { "ar": "مزامنة مع واجهات API الحالية", "en": "Sync with your existing APIs" }
      ]
    },
    {
      "id": "field",
      "badge": { "ar": "زيارات ميدانية", "en": "Field teams" },
      "title": { "ar": "تفتيش وفحص الجودة", "en": "Quality verification" },
      "body": { "ar": "فرق ميدانية تتبع إجراءات التطبيق لقياس جاهزية المتجر وخدمات التوصيل.", "en": "Local field teams follow app-grade checklists for readiness & fulfillment." },
      "points": [
        { "ar": "قياس زمن التحضير والتسليم", "en": "Measure prep & delivery SLAs" },
        { "ar": "تدقيق تجربة الواجهة الأمامية", "en": "Audit the storefront UX" },
        { "ar": "توصيات تحسين قابلة للتنفيذ", "en": "Actionable optimization tips" }
      ]
    },
    {
      "id": "support",
      "badge": { "ar": "24/7", "en": "24/7" },
      "title": { "ar": "مركز دعم متعدد القنوات", "en": "Omni-channel support" },
      "body": { "ar": "نفس وكلاء التطبيق متاحون عبر هذه الواجهة لمتابعة الطلبات أو النزاعات.", "en": "The same in-app agents are available here for orders and escalations." },
      "points": [
        { "ar": "قنوات واتساب، بريد، ولوحة الويب", "en": "WhatsApp, email, and web console" },
        { "ar": "معرّفات محادثة موحدة عبر المنصات", "en": "Unified conversation IDs across channels" },
        { "ar": "تقارير أسبوعية عن التذاكر", "en": "Weekly ticket intelligence reports" }
      ]
    },
    {
      "id": "insights",
      "badge": { "ar": "لوحات فورية", "en": "Instant dashboards" },
      "title": { "ar": "تحليلات وتشغيل آلي", "en": "Analytics & automation" },
      "body": { "ar": "نربط بياناتك بالمنصة لعرض رؤى الطلب، الحملات، ومؤشرات الأداء.", "en": "Connect your data to surface demand, campaign, and SLA insights." },
      "points": [
        { "ar": "مؤشرات أداء قابلة للتخصيص", "en": "Customizable KPIs" },
        { "ar": "تنبيهات بريدية وداخل التطبيق", "en": "Email & in-app alerts" },
        { "ar": "تكامل مع Google Looker وPower BI", "en": "Integrations with Looker & Power BI" }
      ]
    }
  ],
  "testimonials": [
    {
      "quote": { "ar": "الواجهة الجديدة خففت زمن رفع المنتجات إلى أربع دقائق بفضل القوالب الجاهزة.", "en": "The new interface cut listing time to under four minutes thanks to ready-made templates." },
      "person": "ريهام الهديان",
      "role": { "ar": "مديرة التجارة - حياكم", "en": "Commerce Lead · Hayakom" }
    },
    {
      "quote": { "ar": "نفس لوحة التطبيق متاحة للفريق المكتبي، ما أعطانا توحيد في المتابعة.", "en": "The same console our mobile team uses is now on the web, creating true follow-up parity." },
      "person": "مروان الهمداني",
      "role": { "ar": "المؤسس المشارك - توصيل موبايل", "en": "Co-founder · Mobile Delivery" }
    },
    {
      "quote": { "ar": "تقارير مؤشرات الأداء الأسبوعية ساعدتنا على إيقاف التسرب في فرعين خلال شهر.", "en": "Weekly KPI snapshots helped us fix leakage in two branches within a month." },
      "person": "أسيل الضالعي",
      "role": { "ar": "عمليات - كافيه مدار", "en": "Operations · Madar Café" }
    }
  ],
  "insights": [
    { "id": "orders", "value": 1873, "suffix": "+", "change": "+12%", "period": { "ar": "آخر 7 أيام", "en": "Last 7 days" }, "label": { "ar": "طلبات موثقة", "en": "Verified orders" } },
    { "id": "response", "value": 98, "suffix": "%", "change": "+4%", "period": { "ar": "دعم في أقل من 5 دقائق", "en": "<5 min response" }, "label": { "ar": "معدل الرد على الاستفسارات", "en": "Enquiry response rate" } },
    { "id": "retention", "value": 92, "suffix": "%", "change": "-3%", "period": { "ar": "تحسن في سلة التكرار", "en": "Repeat basket uplift" }, "label": { "ar": "احتفاظ المتسوقين", "en": "Shopper retention" } }
  ],
  "timeline": [
    {
      "title": { "ar": "إعداد الهوية وربط البيانات", "en": "Identity & data setup" },
      "body": { "ar": "نربط فروعك، نصمم الصفحات، ونضبط الأذونات مع فريقك.", "en": "Branches, brand assets, and permissions are configured alongside your crew." }
    },
    {
      "title": { "ar": "تشغيل فرقك على الويب", "en": "Team enablement on web" },
      "body": { "ar": "جلسات تدريب حية + مكتبة فيديو باللغتين لتكرار تجربة التطبيق.", "en": "Live training plus a bilingual video library to mirror the in-app experience." }
    },
    {
      "title": { "ar": "تحسين مستمر وتحليلات", "en": "Continuous optimization" },
      "body": { "ar": "تقارير أسبوعية، تنبيهات آنية، ومسارات دعم مشتركة مع التطبيق.", "en": "Weekly reports, instant alerts, and a shared escalation path with the app." }
    }
  ],
  "faq": [
    {
      "question": { "ar": "هل الموقع متصل بنفس واجهات برمجة التطبيق؟", "en": "Is the site connected to the same app APIs?" },
      "answer": { "ar": "نعم، الواجهة تستهلك طبقة API الحالية نفسها، ما يضمن تطابق البيانات والطوابير.", "en": "Yes. The web experience speaks to the very same API layer, ensuring parity on data and queues." }
    },
    {
      "question": { "ar": "كم يستغرق إطلاق تجربة الويب؟", "en": "How long does it take to go live?" },
      "answer": { "ar": "غالبية المتاجر تبحث عن أسبوع واحد بعد تسليم المحتوى والأصول المعتمدة.", "en": "Most merchants launch within a week once content and assets are delivered." }
    },
    {
      "question": { "ar": "هل الواجهة متعددة اللغات؟", "en": "Is the interface bilingual?" },
      "answer": { "ar": "ندعم العربية والإنجليزية افتراضياً، ويمكن إضافة لغات أخرى بناء على الحزمة.", "en": "Arabic and English ship by default, with additional locales available per plan." }
    },
    {
      "question": { "ar": "كيف يتم التكامل مع موقع المتجر الحالي؟", "en": "How do you integrate with an existing site?" },
      "answer": { "ar": "نقدم نطاقاً منفصلاً أو نستضيف الواجهة داخل موقعك عبر iFrame آمن مع نفس الهوية.", "en": "We can ship as a dedicated domain or embed inside your site via a secure iFrame." }
    }
  ],
  "heroBadges": {
    "ar": [
      "+125 متجر جديد هذا الأسبوع",
      "24 مشروع متصل بالخدمات الذكية",
      "92٪ من الطلبات تُسلم خلال 4 ساعات"
    ],
    "en": [
      "+125 new stores this week",
      "24 smart-city projects connected",
      "92% of orders delivered under 4 hours"
    ]
  },
  "liveMetrics": {
    "orders": 180,
    "support": 26
  }
}
JSON;

try {
    return json_decode($json, true, 512, JSON_THROW_ON_ERROR);
} catch (\Throwable) {
    return [];
}
