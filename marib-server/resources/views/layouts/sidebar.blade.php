{{-- =========================
     Sidebar (RTL)
     Admin navigation powered by Spatie permissions (@can / @canany)
========================= --}}
<div id="sidebar" class="active">
  <div class="sidebar-wrapper active">

    {{-- ---------- ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع†ط·آ·ط¢آ·ط·آ¢ط¢آ´ط·آ·ط¢آ·ط·آ¢ط¢آ¹ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ± / ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع†ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط·إ’ط·آ·ط¢آ¸ط·آ¸ط¢آ¹ط·آ·ط¢آ·ط·آ¢ط¢آ¯ط·آ·ط¢آ·ط·آ¢ط¢آ± ---------- --}}
    <div class="sidebar-header position-relative">
      <div class="d-block">
        <div class="logo text-center">
          <a href="{{ url('home') }}">
            <img src="{{ $company_logo ?? '' }}" data-custom-image="{{ url('assets/images/logo/sidebar_logo.png') }}" alt="Logo" />
          </a>
        </div>
      </div>
    </div>

    {{-- ---------- ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط¹â€کط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ¦ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط¢آ¦ط·آ·ط¢آ·ط·آ¢ط¢آ© ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع†ط·آ·ط¢آ·ط·آ¢ط¢آ³ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ¸ط·آ¸ط¢آ¹ط·آ·ط¢آ·ط·آ¢ط¢آ¯ط·آ·ط¢آ·ط·آ¢ط¢آ¨ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ± ---------- --}}
    <div class="sidebar-menu" style="direction: rtl; text-align: right;">
      <ul class="menu">

        {{-- ط·آ£ط¢آ¯ط·آ·ط¹ط›ط·آ¢ط¢آ½?ط·آ£ط¢آ¯ط·آ·ط¹ط›ط·آ¢ط¢آ½?ط·آ£ط¢آ¯ط·آ·ط¹ط›ط·آ¢ط¢آ½?ط·آ£ط¢آ¯ط·آ·ط¹ط›ط·آ¢ط¢آ½? ط·آ£ط¢آ¯ط·آ·ط¹ط›ط·آ¢ط¢آ½?ط·آ£ط¢آ¯ط·آ·ط¹ط›ط·آ¢ط¢آ½?ط·آ£ط¢آ¯ط·آ·ط¹ط›ط·آ¢ط¢آ½?ط·آ£ط¢آ¯ط·آ·ط¹ط›ط·آ¢ط¢آ½?ط·آ£ط¢آ¯ط·آ·ط¹ط›ط·آ¢ط¢آ½?ط·آ£ط¢آ¯ط·آ·ط¹ط›ط·آ¢ط¢آ½? --}}
        @if(!auth()->check() || auth()->user()->account_type !== \App\Models\User::ACCOUNT_TYPE_SELLER)
          <li class="sidebar-item">
            <a href="{{ route('home') }}" class="sidebar-link">
              <i class="bi bi-house"></i>
              <span class="menu-item">{{ __('Dashboard') }}</span>
            </a>
          </li>
        @endif


        @canany(['category-list','category-create','category-update','category-delete',
                 'custom-field-list','custom-field-create','custom-field-update','custom-field-delete'])
          <div class="sidebar-new-title">{{ __('Ads Listing') }}</div>

          @canany(['category-list','category-create','category-update','category-delete'])
            <li class="sidebar-item sidebar-submenus">
              <a href="{{ route('category.index') }}" class="sidebar-link">
                <i class="bi bi-list-task"></i>
                <span class="menu-item">{{ __('Categories') }}</span>
              </a>
            </li>
          @endcanany

          @canany(['custom-field-list','custom-field-create','custom-field-update','custom-field-delete'])
            <li class="sidebar-item sidebar-submenus">
              <a href="{{ route('custom-fields.index') }}" class="sidebar-link">
                <i class="bi bi-columns-gap"></i>
                <span class="menu-item">{{ __('Custom Fields') }}</span>
              </a>
            </li>
          @endcanany
        @endcanany


        {{-- =========================
            Items Management (items + tips)
        ========================= --}}
        @canany(['item-list','item-create','item-update','item-delete',
                'tip-list','tip-create','tip-update','tip-delete'])
        <div class="sidebar-new-title">{{ __('Items Management') }}</div>

        @canany(['item-list','item-create','item-update','item-delete'])
            <li class="sidebar-item">
            <a href="{{ route('item.index') }}" class="sidebar-link">
                <i class="bi bi-ui-radios-grid"></i>
                <span class="menu-item">{{ __('Items') }}</span>
            </a>
            </li>
        @endcanany

        @canany(['tip-list','tip-create','tip-update','tip-delete'])
            <li class="sidebar-item">
            <a href="{{ route('tips.index') }}" class="sidebar-link">
                <i class="bi bi-lightbulb"></i>
                <span class="menu-item">{{ __('Tips') }}</span>
            </a>
            </li>
        @endcanany
        @endcanany

        {{-- =========================
             Package Management (listing packages & payments)
        ========================== --}}
        @canany(['item-listing-package-list','item-listing-package-create','item-listing-package-update','item-listing-package-delete',
                 'advertisement-package-list','advertisement-package-create','advertisement-package-update','advertisement-package-delete',
                 'user-package-list','payment-transactions-list',
                 'currency-rate-list','currency-rate-create','currency-rate-edit','currency-rate-delete',
                 'metal-rate-list','metal-rate-create','metal-rate-edit','metal-rate-delete','metal-rate-schedule'])
                 
                 <div class="sidebar-new-title">{{ __('Package Management') }}</div>

          @canany(['item-listing-package-list','item-listing-package-create','item-listing-package-update','item-listing-package-delete',
                   'advertisement-package-list','advertisement-package-create','advertisement-package-update','advertisement-package-delete'])
            <li class="sidebar-item sidebar-submenus">
              <a href="{{ route('package.index') }}" class="sidebar-link">
                <i class="bi bi-list"></i>
                <span class="menu-item">{{ __('Item Listing Package') }}</span>
              </a>
            </li>
          @endcanany

          @canany(['advertisement-package-list','advertisement-package-create','advertisement-package-update','advertisement-package-delete'])
            <li class="sidebar-item sidebar-submenus">
              <a href="{{ route('package.advertisement.index') }}" class="sidebar-link">
                <i class="bi bi-badge-ad"></i>
                <span class="menu-item">{{ __('Advertisement Package') }}</span>
              </a>
            </li>
          @endcanany

          @can('user-package-list')
            <li class="sidebar-item sidebar-submenus">
              <a href="{{ route('package.users.index') }}" class="sidebar-link">
                <i class="bi bi-person-badge-fill"></i>
                <span class="menu-item">{{ __('User Packages') }}</span>
              </a>
            </li>
          @endcan

          @can('payment-transactions-list')
            <li class="sidebar-item sidebar-submenus">
              <a href="{{ route('package.payment-transactions.index') }}" class="sidebar-link">
                <i class="bi bi-cash-coin"></i>
                <span class="menu-item">{{ __('Payment Transactions') }}</span>
              </a>
            </li>
          @endcan


          @canany(['manual-payments-list','manual-payments-review'])
            <li class="sidebar-item">
              <a href="{{ route('payment-requests.index') }}" class="sidebar-link">
                <i class="bi bi-wallet2"></i>
                <span class="menu-item">{{ __('sidebar.manual_payment_requests') }}</span>
              </a>
            </li>
          @endcanany


          @can('wallet-manage')
            <li class="sidebar-item">
              <a href="{{ route('wallet.index') }}" class="sidebar-link">
                <i class="bi bi-wallet-fill"></i>
                <span class="menu-item">{{ __('Wallet') }}</span>
              </a>
            </li>
            <li class="sidebar-item">
              @php($pendingCount = $pendingWalletWithdrawalCount ?? 0)
              <a href="{{ route('wallet.withdrawals.index') }}" class="sidebar-link d-flex align-items-center justify-content-between gap-2">
                <span class="d-flex align-items-center gap-2">
                  <i class="bi bi-arrow-down-circle"></i>
                  <span class="menu-item">{{ __('Wallet Withdrawal Requests') }}</span>
                </span>
                @if($pendingCount > 0)
                  <span class="badge bg-danger rounded-pill">{{ $pendingCount }}</span>
                @endif
              </a>
            </li>

          @endcan



          @can('wifi-cabin-manage')
            <div class="sidebar-new-title">{{ __('Various Services') }}</div>

            <li class="sidebar-item">
              <a href="{{ route('wifi.index') }}" class="sidebar-link">
                <i class="bi bi-wifi"></i>
                <span class="menu-item">{{ __('WiFi Cabin Management') }}</span>
              </a>
            </li>
          @endcan



          @canany(['currency-rate-list','currency-rate-create','currency-rate-edit','currency-rate-delete'])
            <li class="sidebar-item sidebar-submenus">
              <a href="{{ route('currency.index') }}" class="sidebar-link">
                <i class="bi bi-currency-exchange"></i>
                <span class="menu-item">{{ __('Currency Rates') }}</span>
              </a>
            </li>
          @endcanany

          @canany(['metal-rate-list','metal-rate-create','metal-rate-edit','metal-rate-delete','metal-rate-schedule'])
            <li class="sidebar-item sidebar-submenus">
              <a href="{{ route('metal-rates.index') }}" class="sidebar-link">
                <i class="bi bi-gem"></i>
                <span class="menu-item">{{ __('Metal Rates') }}</span>
              </a>
            </li>
          @endcanany

        @endcanany


        {{-- =========================
            Seller Management (verification, reviews, access)
        ========================== --}}
        @canany(['seller-verification-field-list','seller-verification-field-create','seller-verification-field-update','seller-verification-field-delete',
                 'seller-verification-request-list','seller-verification-request-create','seller-verification-request-update','seller-verification-request-delete',
                 'seller-review-list','seller-review-update','seller-review-delete',
                 'seller-store-settings-manage'])
                 
                 <div class="sidebar-new-title">{{ __('Seller Management') }}</div>

          @canany(['seller-verification-field-list','seller-verification-field-create','seller-verification-field-update','seller-verification-field-delete',
                   'seller-verification-request-list','seller-verification-request-create','seller-verification-request-update','seller-verification-request-delete'])
            <li class="sidebar-item">
              <a href="{{ route('seller-verification.dashboard') }}" class="sidebar-link">
                <i class="bi bi-shield-lock"></i>
                <span class="menu-item">{{ __('الحسابات الموثقة') }}</span>
              </a>
            </li>
          @endcanany

          {{-- ط·آ·ط¢آ·ط·آ¢ط¢آ­ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط¹â€کط·آ·ط¢آ¸ط·آ«أ¢â‚¬آ ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع† ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع†ط·آ·ط¢آ·ط·آ¹ط¢آ¾ط·آ·ط¢آ¸ط·آ«أ¢â‚¬آ ط·آ·ط¢آ·ط·آ¢ط¢آ«ط·آ·ط¢آ¸ط·آ¸ط¢آ¹ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط¹â€ک (ط·آ·ط¢آ·ط·آ¢ط¢آ¥ط·آ·ط¢آ·ط·آ¢ط¢آ¯ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ±ط·آ·ط¢آ¸ط·آ¸ط¢آ¹ط·آ·ط¢آ·ط·آ¢ط¢آ©) --}}
          @canany(['seller-review-list','seller-review-update','seller-review-delete'])
            <li class="sidebar-item">
              <a href="{{ route('seller-review.index') }}" class="sidebar-link">
                <i class="bi bi-star-half"></i>
                <span class="menu-item">{{ __('Seller Review') }}</span>
              </a>
            </li>
          @endcanany

          @canany(['seller-review-list','seller-review-update','seller-review-delete'])
            <li class="sidebar-item">
              <a href="{{ route('seller-review.report') }}" class="sidebar-link">
                <i class="bi bi-list-stars"></i>
                <span class="menu-item">{{ __('Seller Review Report') }}</span>
              </a>
            </li>
          @endcanany


          @can('seller-store-settings-manage')
            <li class="sidebar-item">
              <a href="{{ route('seller-store-settings.index') }}" class="sidebar-link">
                <i class="bi bi-gear"></i>
                <span class="menu-item">{{ __('Store Settings') }}</span>
              </a>
            </li>
          @endcan

        @endcanany

          @if(auth()->check() && auth()->user()->account_type === \App\Models\User::ACCOUNT_TYPE_SELLER)
            <li class="sidebar-item">
              <a href="{{ route('merchant.dashboard') }}" class="sidebar-link">
                <i class="bi bi-shop"></i>
                <span class="menu-item">{{ __('sidebar.store_dashboard') }}</span>
              </a>
            </li>
            <li class="sidebar-item">
              <a href="{{ route('merchant.orders.index') }}" class="sidebar-link">
                <i class="bi bi-receipt-cutoff"></i>
                <span class="menu-item">{{ __('sidebar.store_orders') }}</span>
              </a>
            </li>
            <li class="sidebar-item">
              <a href="{{ route('merchant.manual-payments.index') }}" class="sidebar-link">
                <i class="bi bi-bank"></i>
                <span class="menu-item">{{ __('sidebar.store_manual_payments') }}</span>
              </a>
            </li>
            <li class="sidebar-item">
              <a href="{{ route('merchant.wallet.index') }}" class="sidebar-link">
                <i class="bi bi-wallet2"></i>
                <span class="menu-item">{{ __('sidebar.store_wallet') }}</span>
              </a>
            </li>
            <li class="sidebar-item">
              <a href="{{ route('merchant.products.index') }}" class="sidebar-link">
                <i class="bi bi-bag-check"></i>
                <span class="menu-item">{{ __('sidebar.product_management') }}</span>
              </a>
            </li>
            <li class="sidebar-item">
              <a href="{{ route('merchant.coupons.index') }}" class="sidebar-link">
                <i class="bi bi-ticket-perforated"></i>
                <span class="menu-item">{{ __('sidebar.coupons_menu') }}</span>
              </a>
            </li>
            <li class="sidebar-item">
              <a href="{{ route('merchant.reports.orders') }}" class="sidebar-link">
                <i class="bi bi-graph-up"></i>
                <span class="menu-item">{{ __('sidebar.orders_reports_menu') }}</span>
              </a>
            </li>
            <li class="sidebar-item">
              <a href="{{ route('merchant.reports.sales') }}" class="sidebar-link">
                <i class="bi bi-cash-coin"></i>
                <span class="menu-item">{{ __('sidebar.sales_reports_menu') }}</span>
              </a>
            </li>
            <li class="sidebar-item">
              <a href="{{ route('merchant.reports.customers') }}" class="sidebar-link">
                <i class="bi bi-people"></i>
                <span class="menu-item">{{ __('sidebar.customers_reports_menu') }}</span>
              </a>
            </li>
            <li class="sidebar-item">
              <a href="{{ route('merchant.settings') }}" class="sidebar-link">
                <i class="bi bi-gear"></i>
                <span class="menu-item">{{ __('sidebar.store_settings') }}</span>
              </a>
            </li>
          @endif

        @can('seller-store-settings-manage')
          <div class="sidebar-new-title">{{ __('Stores & Merchants') }}</div>
          <li class="sidebar-item">
            <a href="{{ route('merchant-stores.index') }}" class="sidebar-link">
              <i class="bi bi-shop-window"></i>
              <span class="menu-item">{{ __('sidebar.merchant_directory') }}</span>
            </a>
          </li>
        @endcan


        {{-- =========================
             Home Screen Management
             ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع†ط·آ·ط¢آ·ط·آ¢ط¢آ³ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع†ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ¸ط·آ¸ط¢آ¹ط·آ·ط¢آ·ط·آ¢ط¢آ¯ط·آ·ط¢آ·ط·آ¢ط¢آ± + ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع†ط·آ·ط¢آ·ط·آ¢ط¢آ£ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط¹â€کط·آ·ط¢آ·ط·آ¢ط¢آ³ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط¢آ¦ ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع†ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط¢آ¦ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط¢آ¦ط·آ·ط¢آ¸ط·آ¸ط¢آ¹ط·آ·ط¢آ·ط·آ¢ط¢آ²ط·آ·ط¢آ·ط·آ¢ط¢آ©
        ========================== --}}
        @canany(['slider-list','slider-create','slider-update','slider-delete'])
          <div class="sidebar-new-title">{{ __('Home Screen Management') }}</div>

          @canany(['slider-list','slider-create','slider-update','slider-delete'])
            <li class="sidebar-item">
              <a href="{{ route('slider.index') }}" class="sidebar-link">
                <i class="bi bi-sliders2"></i>
                <span class="menu-item">{{ __('Slider') }}</span>
              </a>
            </li>
          @endcanany
            <li class="sidebar-item">
              <a href="{{ route('featured-ads-configs.index') }}" class="sidebar-link">
                <i class="bi bi-stars"></i>
                <span class="menu-item">إعلانات مميزة</span>
              </a>
            </li>
        @endcanany


        {{-- =========================
             Place/Location Management
             ط·آ·ط¢آ·ط·آ¢ط¢آ¯ط·آ·ط¢آ¸ط·آ«أ¢â‚¬آ ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع†/ط·آ·ط¢آ¸ط·آ«أ¢â‚¬آ ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع†ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ¸ط·آ¸ط¢آ¹ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¹ط¢آ¾/ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط¢آ¦ط·آ·ط¢آ·ط·آ¢ط¢آ¯ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط¢آ /ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط¢آ¦ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط¢آ ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط¹â€ک
        ========================== --}}
        @canany(['country-list','country-create','country-update','country-delete',
                 'state-list','state-create','state-update','state-delete',
                 'city-list','city-create','city-update','city-delete',
                 'area-list','area-create','area-update','area-delete'])
          <div class="sidebar-new-title">{{ __('Place/Location Management') }}</div>

          @canany(['country-list','country-create','country-update','country-delete'])
            <li class="sidebar-item">
              <a href="{{ route('countries.index') }}" class="sidebar-link">
                <i class="bi bi-globe"></i>
                <span class="menu-item">{{ __('Countries') }}</span>
              </a>
            </li>
          @endcanany

          @canany(['state-list','state-create','state-update','state-delete'])
            <li class="sidebar-item">
              <a href="{{ route('states.index') }}" class="sidebar-link">
                <i class="fa fa-map-marked-alt"></i>
                <span class="menu-item">{{ __('States') }}</span>
              </a>
            </li>
          @endcanany

          @canany(['city-list','city-create','city-update','city-delete'])
            <li class="sidebar-item">
              <a href="{{ route('cities.index') }}" class="sidebar-link">
                <i class="fa fa-map-marker-alt"></i>
                <span class="menu-item">{{ __('Cities') }}</span>
              </a>
            </li>
          @endcanany

          @canany(['area-list','area-create','area-update','area-delete'])
            <li class="sidebar-item">
              <a href="{{ route('area.index') }}" class="sidebar-link">
                <i class="fa fa-map-marker"></i>
                <span class="menu-item">{{ __('Areas') }}</span>
              </a>
            </li>
          @endcanany
        @endcanany


        {{-- =========================
             Reports Management
             ط·آ·ط¢آ·ط·آ¢ط¢آ£ط·آ·ط¢آ·ط·آ¢ط¢آ³ط·آ·ط¢آ·ط·آ¢ط¢آ¨ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ¨ ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع†ط·آ·ط¢آ·ط·آ¢ط¢آ¨ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع†ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ·أ¢â‚¬ط›ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¹ط¢آ¾ + ط·آ·ط¢آ·ط·آ¢ط¢آ¨ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع†ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ·أ¢â‚¬ط›ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¹ط¢آ¾ ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع†ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط¢آ¦ط·آ·ط¢آ·ط·آ¢ط¢آ³ط·آ·ط¢آ·ط·آ¹ط¢آ¾ط·آ·ط¢آ·ط·آ¢ط¢آ®ط·آ·ط¢آ·ط·آ¢ط¢آ¯ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط¢آ¦ط·آ·ط¢آ¸ط·آ¸ط¢آ¹ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط¢آ 
        ========================== --}}
        @canany(['report-reason-list','report-reason-create','report-reason-update','report-reason-delete',
                 'user-report-list','user-report-create','user-report-update','user-report-delete'])
          <div class="sidebar-new-title">{{ __('Reports Management') }}</div>

          @canany(['report-reason-list','report-reason-create','report-reason-update','report-reason-delete'])
            <li class="sidebar-item">
              <a href="{{ route('report-reasons.index') }}" class="sidebar-link">
                <i class="bi bi-flag"></i>
                <span class="menu-item">{{ __('Report Reasons') }}</span>
              </a>
            </li>
          @endcanany

          @canany(['user-report-list','user-report-create','user-report-update','user-report-delete'])
            <li class="sidebar-item">
              <a href="{{ route('report-reasons.user-reports.index') }}" class="sidebar-link">
                <i class="bi bi-person"></i>
                <span class="menu-item">{{ __('User Reports') }}</span>
              </a>
            </li>
          @endcanany
                    @can('reports-orders')
            <li class="sidebar-item sidebar-submenus">
              <a href="{{ route('reports.payment-requests') }}" class="sidebar-link">
                <i class="bi bi-graph-up"></i>
                <span class="menu-item">{{ __('Payment Request Analytics') }}</span>
              </a>
            </li>
          @endcan
        @endcanany


        {{-- =========================
             ط·آ·ط¢آ·ط·آ¢ط¢آ¥ط·آ·ط¢آ·ط·آ¢ط¢آ¯ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ±ط·آ·ط¢آ·ط·آ¢ط¢آ© ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع†ط·آ·ط¢آ¸ط·آ¦أ¢â‚¬â„¢ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط¢آ¦ط·آ·ط¢آ·ط·آ¢ط¢آ¨ط·آ·ط¢آ¸ط·آ¸ط¢آ¹ط·آ·ط¢آ¸ط·آ«أ¢â‚¬آ ط·آ·ط¢آ·ط·آ¹ط¢آ¾ط·آ·ط¢آ·ط·آ¢ط¢آ±
        ========================== --}}
        @canany([
            'computer-ads-list','computer-ads-create','computer-ads-update','computer-ads-delete',
            'computer-requests-list','computer-requests-create','computer-requests-update','computer-requests-delete',
            'computer-orders-list','orders-list','staff-list','staff-create','staff-update','staff-delete',
            'reports-orders','reports-sales','reports-customers','reports-statuses','chat-monitor-list'
        ])
          <div class="sidebar-new-title">{{ __("sidebar.computer_section_title") }}</div>

          <li class="sidebar-item">
            <a href="{{ route('item.computer') }}" class="sidebar-link">
              <i class="bi bi-laptop"></i>
               <span class="menu-item">{{ __('sidebar.computer_section_menu') }}</span>
            </a>
          </li>
        @endcanany


        {{-- =========================
             ط·آ·ط¢آ·ط·آ¢ط¢آ¥ط·آ·ط¢آ·ط·آ¢ط¢آ¯ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ±ط·آ·ط¢آ·ط·آ¢ط¢آ© ط·آ·ط¢آ·ط·آ¢ط¢آ´ط·آ·ط¢آ¸ط·آ¸ط¢آ¹ ط·آ·ط¢آ·ط·آ¢ط¢آ¥ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط¢آ 
        ========================== --}}
        @canany(['shein-products-list','shein-products-create','shein-products-update','shein-products-delete',
                 'shein-orders-list','shein-orders-create','shein-orders-update','shein-orders-delete'])
          <div class="sidebar-new-title">{{ __("sidebar.shein_section_title") }}</div>

          <li class="sidebar-item">
            <a href="{{ route('item.shein.index') }}" class="sidebar-link">
              <i class="bi bi-bag-heart"></i>
               <span class="menu-item">{{ __('sidebar.shein_section_menu') }}</span>
            </a>
          </li>
        @endcanany


        {{-- =========================
             Promotional Management
             ط·آ·ط¢آ·ط·آ¹ط¢آ¾ط·آ·ط¢آ·ط·آ¢ط¢آ­ط·آ·ط¢آ·ط·آ¢ط¢آ¯ط·آ·ط¢آ¸ط·آ¸ط¢آ¹ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¹ط¢آ¾ + ط·آ·ط¢آ·ط·آ¢ط¢آ¥ط·آ·ط¢آ·ط·آ¢ط¢آ­ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع†ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¹ط¢آ¾ ط·آ·ط¢آ¸ط·آ«أ¢â‚¬آ ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط¢آ ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط¹â€کط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ· + ط·آ·ط¢آ·ط·آ¢ط¢آ¥ط·آ·ط¢آ·ط·آ¢ط¢آ±ط·آ·ط¢آ·ط·آ¢ط¢آ³ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع† ط·آ·ط¢آ·ط·آ¢ط¢آ¥ط·آ·ط¢آ·ط·آ¢ط¢آ´ط·آ·ط¢آ·ط·آ¢ط¢آ¹ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ± + ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع†ط·آ·ط¢آ·ط·آ¢ط¢آ¹ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط¢آ¦ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع†ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ·ط¥â€™
        ========================== --}}
        @canany(['challenge-list','challenge-create','challenge-edit','challenge-delete',
                 'referral-list',
                 'notifications-send',
                 'customer-list','customer-create','customer-update','customer-delete'])
          <div class="sidebar-new-title">{{ __('Promotional Management') }}</div>

          @canany(['challenge-list','challenge-create','challenge-edit','challenge-delete'])
            <li class="sidebar-item">
              <a href="{{ route('challenges.index') }}" class="sidebar-link">
                <i class="bi bi-trophy"></i>
                <span class="menu-item">{{ __('Challenges') }}</span>
              </a>
            </li>
          @endcanany

          @can('referral-list')
            <li class="sidebar-item">
              <a href="{{ route('referrals.index') }}" class="sidebar-link">
                <i class="bi bi-people"></i>
                <span class="menu-item">{{ __('Referrals & Points') }}</span>
              </a>
            </li>
          @endcan

          @can('notifications-send')
            <li class="sidebar-item">
              <a href="{{ route('notification.index') }}" class="sidebar-link">
                <i class="bi bi-bell"></i>
                <span class="menu-item">{{ __('Send Notification') }}</span>
              </a>
            </li>
          @endcan

          @canany(['customer-list','customer-create','customer-update','customer-delete'])
            <div class="sidebar-new-title">{{ __('Customers') }}</div>
            <li class="sidebar-item">
              <a href="{{ route('customer.index') }}" class="sidebar-link">
                <i class="bi bi-people"></i>
                <span class="menu-item">{{ __('Customers') }}</span>
              </a>
            </li>
          @endcanany
        @endcanany


        {{-- =========================
             Staff Management
             ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع†ط·آ·ط¢آ·ط·آ¢ط¢آ£ط·آ·ط¢آ·ط·آ¢ط¢آ¯ط·آ·ط¢آ¸ط·آ«أ¢â‚¬آ ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ± + ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع†ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط¢آ¦ط·آ·ط¢آ¸ط·آ«أ¢â‚¬آ ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ·ط¢آ¸ط·آ¸ط¢آ¾ط·آ·ط¢آ¸ط·آ«أ¢â‚¬آ ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط¢آ 
        ========================== --}}
        @canany(['role-list','role-create','role-update','role-delete',
                 'staff-list','staff-create','staff-update','staff-delete'])
          <div class="sidebar-new-title">{{ __('Staff Management') }}</div>

          @canany(['role-list','role-create','role-update','role-delete'])
            <li class="sidebar-item">
              <a href="{{ route('roles.index') }}" class="sidebar-link">
                <i class="bi bi-person-bounding-box"></i>
                <span class="menu-item">{{ __('Role') }}</span>
              </a>
            </li>
          @endcanany

          @canany(['staff-list','staff-create','staff-update','staff-delete'])
            <li class="sidebar-item">
              <a href="{{ route('staff.index') }}" class="sidebar-link">
                <i class="bi bi-gear"></i>
                <span class="menu-item">{{ __('Staff Management') }}</span>
              </a>
            </li>
          @endcanany
        @endcanany


        {{-- =========================
             Services Management
             ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع†ط·آ·ط¢آ·ط·آ¢ط¢آ®ط·آ·ط¢آ·ط·آ¢ط¢آ¯ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط¢آ¦ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¹ط¢آ¾ + ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع†ط·آ·ط¢آ·ط·آ¢ط¢آ¨ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¹ط¢آ¾ ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع†ط·آ·ط¢آ·ط·آ¢ط¢آ®ط·آ·ط¢آ·ط·آ¢ط¢آ¯ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط¢آ¦ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¹ط¢آ¾
        ========================== --}}


        @canany([
            'service-list','service-create','service-update','service-delete',
            'service-requests-list','service-requests-create','service-requests-update','service-requests-delete'
        ])



          <div class="sidebar-new-title">{{ __("sidebar.services_section_title") }}</div>

          <li class="sidebar-item">
            <a href="{{ route('services.index') }}" class="sidebar-link">
              <i class="bi bi-tools"></i>
               <span class="menu-item">{{ __('sidebar.services_section_menu') }}</span>
            </a>
          </li>


        @endcanany


        {{-- =========================
             Travel / Blog
             (ط·آ·ط¢آ·ط·آ¹ط¢آ¾ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط¢آ¦ ط·آ·ط¢آ·ط·آ¹ط¢آ¾ط·آ·ط¢آ·ط·آ¢ط¢آµط·آ·ط¢آ·ط·آ¢ط¢آ­ط·آ·ط¢آ¸ط·آ¸ط¢آ¹ط·آ·ط¢آ·ط·آ¢ط¢آ­ ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع†ط·آ·ط¢آ·ط·آ¢ط¢آµط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع†ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ­ط·آ·ط¢آ¸ط·آ¸ط¢آ¹ط·آ·ط¢آ·ط·آ¢ط¢آ© ط·آ·ط¢آ·ط·آ¢ط¢آ¥ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع†ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط¢آ° blog-list)
        ========================== --}}
        @canany(['blog-list','blog-create','blog-update','blog-delete'])
          <div class="sidebar-new-title">{{ __('Travel Management') }}</div>
          <li class="sidebar-item">
            <a href="{{ route('blog.index') }}" class="sidebar-link">
              <i class="bi bi-pencil"></i>
              <span class="menu-item">{{ __('Travel') }}</span>
            </a>
          </li>
        @endcanany


        {{-- =========================
             ط¸â€¦ط·آ±ط·آ§ط¸â€ڑط·آ¨ط·آ© ط·آ§ط¸â€‍ط¸â€¦ط·آ­ط·آ§ط·آ¯ط·آ«ط·آ§ط·ع¾
        ========================== --}}
        @can('chat-monitor-list')
          <div class="sidebar-new-title">{{ __("sidebar.chat_monitor_title") }}</div>
          <li class="sidebar-item">
            <a href="{{ route('chat-monitor.index') }}?locale={{ App::getLocale() }}" class="sidebar-link">
              <i class="bi bi-chat-dots-fill"></i>
              <span class="menu-item">{{ __('sidebar.chat_monitor_menu') }}</span>
            </a>
          </li>
        @endcan


        {{-- =========================
             ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط¢آ ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط¢آ¦ ط·آ·ط¢آ·ط·آ¢ط¢آ¥ط·آ·ط¢آ·ط·آ¢ط¢آ¯ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ±ط·آ·ط¢آ·ط·آ¢ط¢آ© ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع†ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع†ط·آ·ط¢آ·ط·آ¢ط¢آ¨ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¹ط¢آ¾
             ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع†ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع†ط·آ·ط¢آ·ط·آ¢ط¢آ¨ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¹ط¢آ¾ + ط·آ·ط¢آ·ط·آ¢ط¢آ®ط·آ·ط¢آ·ط·آ¢ط¢آ¯ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط¢آ¦ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¹ط¢آ¾ ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع†ط·آ·ط¢آ·ط·آ¹ط¢آ¾ط·آ·ط¢آ¸ط·آ«أ¢â‚¬آ ط·آ·ط¢آ·ط·آ¢ط¢آµط·آ·ط¢آ¸ط·آ¸ط¢آ¹ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع† + ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع†ط·آ·ط¢آ·ط·آ¹ط¢آ¾ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط¹â€کط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ±ط·آ·ط¢آ¸ط·آ¸ط¢آ¹ط·آ·ط¢آ·ط·آ¢ط¢آ±
        ========================== --}}
        @canany(['orders-list','orders-create','orders-update','orders-delete',
                 'delivery-prices-list','delivery-prices-create','delivery-prices-update','delivery-prices-delete',
                 'reports-orders','reports-sales','reports-customers','reports-statuses'])
          <div class="sidebar-new-title">{{ __("sidebar.orders_delivery_title") }}</div>

          @canany(['orders-list','orders-create','orders-update','orders-delete'])
            <li class="sidebar-item">
              <a href="{{ route('orders.index') }}" class="sidebar-link">
                <i class="bi bi-cart-fill"></i>
                <span class="menu-item">{{ __('sidebar.platform_orders_menu') }}</span>
              </a>
            </li>
          @endcanany

          @canany(['delivery-prices-list','delivery-prices-create','delivery-prices-update','delivery-prices-delete'])
            <li class="sidebar-item">
              <a href="{{ route('delivery-prices.index') }}" class="sidebar-link">
                <i class="bi bi-truck"></i>
                 <span class="menu-item">{{ __('sidebar.delivery_prices_menu') }}</span>
              </a>
            </li>
          @endcanany

          @can('manual-payments-review')
            <li class="sidebar-item">
              <a href="{{ route('delivery.requests.index') }}" class="sidebar-link">
                <i class="bi bi-send-plus"></i>
                 <span class="menu-item">{{ __('sidebar.delivery_requests_menu') }}</span>
              </a>
            </li>
            <li class="sidebar-item">
              <a href="{{ route('delivery.agents.index') }}" class="sidebar-link">
                <i class="bi bi-person-lines-fill"></i>
                 <span class="menu-item">{{ __('sidebar.delivery_agents_menu') }}</span>
              </a>
            </li>
          @endcan


                    @canany(['coupon-list','coupon-create','coupon-edit'])
            <li class="sidebar-item">
              <a href="{{ route('coupons.index') }}" class="sidebar-link">
                <i class="bi bi-ticket-perforated"></i>
                <span class="menu-item">{{ __('sidebar.coupons_menu') }}</span>
              </a>
            </li>
          @endcanany

          @can('reports-orders')
            <li class="sidebar-item">
              <a href="{{ route('reports.index') }}" class="sidebar-link">
                <i class="bi bi-graph-up"></i>
                <span class="menu-item">{{ __('sidebar.orders_reports_menu') }}</span>
              </a>
            </li>
          @endcan

          @can('reports-sales')
            <li class="sidebar-item">
              <a href="{{ route('reports.sales') }}" class="sidebar-link">
                <i class="bi bi-cash-stack"></i>
                <span class="menu-item">{{ __('sidebar.sales_reports_menu') }}</span>
              </a>
            </li>
          @endcan

          @can('reports-customers')
            <li class="sidebar-item">
              <a href="{{ route('reports.customers') }}" class="sidebar-link">
                <i class="bi bi-people-fill"></i>
                <span class="menu-item">{{ __('sidebar.customers_reports_menu') }}</span>
              </a>
            </li>
          @endcan

          @can('reports-statuses')
            <li class="sidebar-item">
              <a href="{{ route('reports.statuses') }}" class="sidebar-link">
                <i class="bi bi-pie-chart-fill"></i>
                <span class="menu-item">{{ __('sidebar.statuses_reports_menu') }}</span>
              </a>
            </li>
          @endcan
        @endcanany


        {{-- =========================
             FAQ & Contact
        ========================== --}}
        @canany(['faq-create','faq-list','faq-update','faq-delete','contact-us-list','contact-us-update','contact-us-delete'])
          <div class="sidebar-new-title">{{ __('FAQ') }}</div>

          @canany(['contact-us-list','contact-us-update','contact-us-delete'])
            <li class="sidebar-item">
              <a href="{{ route('contact-us.index') }}" class="sidebar-link">
                <i class="bi bi-person-bounding-box"></i>
                <span class="menu-item">{{ __('User Queries') }}</span>
              </a>
            </li>
          @endcanany

          @canany(['faq-create','faq-list','faq-update','faq-delete'])
            <li class="sidebar-item">
              <a href="{{ route('faq.index') }}" class="sidebar-link">
                <i class="bi bi-question-square-fill"></i>
                <span class="menu-item">{{ __('FAQs') }}</span>
              </a>
            </li>
          @endcanany
        @endcanany


        {{-- =========================
             System Settings
        ========================== --}}
        @canany([
          'settings-update',
        ])
        
        <div class="sidebar-new-title">{{ __('System Settings') }}</div>

          @can('settings-update')
            <li class="sidebar-item">
              <a href="{{ route('settings.index') }}" class="sidebar-link">
                <i class="bi bi-gear"></i>
                <span class="menu-item">{{ __('Settings') }}</span>
              </a>
            </li>

            <li class="sidebar-item">
              <a href="{{ route('settings.legal-numbering.index') }}" class="sidebar-link">
                <i class="bi bi-hash"></i>
                <span class="menu-item">{{ __('Legal Numbering') }}</span>
              </a>
            </li>

          @endcan
        @endcanany

      </ul>
    </div>
  </div>
</div>








