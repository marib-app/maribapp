<header>
    <nav class="navbar navbar-expand navbar-light">
        <div class="container-fluid">

            <div class="col-6 row d-flex align-items-center">
                <div class="col-1 me-3 me-md-2">
                    <a href="#" class="burger-btn d-block"><i class="bi bi-justify fs-3"></i></a>

                    <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarSupportedContent" aria-controls="navbarSupportedContent" aria-expanded="false" aria-label="Toggle navigation">
                        <span class="navbar-toggler-icon"></span>
                    </button>
                </div>

                @if(config('app.demo_mode'))
                    <div class="col-2">
                        <span class="badge alert-info primary-background-color">Demo Mode</span>
                    </div>
                @endif
            </div>
            <div class="col-6 justify-content-end d-flex">
                <div class="collapse navbar-collapse" id="navbarSupportedContent">
                    <div class="theme-toggle me-3">
                        <button id="theme-toggle-btn" class="btn btn-light btn-sm">
                            <i class="bi bi-sun-fill" id="theme-icon"></i>
                        </button>
                    </div>
                    <script>
                        // تطبيق الوضع المظلم مباشرة قبل تحميل الصفحة
                        (function() {
                            const savedTheme = localStorage.getItem('theme');
                            if (savedTheme === 'dark') {
                                document.documentElement.setAttribute('data-bs-theme', 'dark');
                                document.body.classList.add('dark-mode');
                            }
                        })();

                        document.addEventListener('DOMContentLoaded', function() {
                            const themeToggleBtn = document.getElementById('theme-toggle-btn');
                            const themeIcon = document.getElementById('theme-icon');
                            const htmlElement = document.documentElement;
                            const body = document.body;

                            // تحديث أيقونة الثيم عند تحميل الصفحة
                            if (htmlElement.getAttribute('data-bs-theme') === 'dark') {
                                themeIcon.classList.remove('bi-sun-fill');
                                themeIcon.classList.add('bi-moon-fill');
                            }

                            themeToggleBtn.addEventListener('click', function() {
                                if (htmlElement.getAttribute('data-bs-theme') === 'dark') {
                                    disableDarkMode();
                                } else {
                                    enableDarkMode();
                                }
                            });

                            function enableDarkMode() {
                                htmlElement.setAttribute('data-bs-theme', 'dark');
                                body.classList.add('dark-mode');
                                themeIcon.classList.remove('bi-sun-fill');
                                themeIcon.classList.add('bi-moon-fill');
                                localStorage.setItem('theme', 'dark');
                            }

                            function disableDarkMode() {
                                htmlElement.setAttribute('data-bs-theme', 'light');
                                body.classList.remove('dark-mode');
                                themeIcon.classList.remove('bi-moon-fill');
                                themeIcon.classList.add('bi-sun-fill');
                                localStorage.setItem('theme', 'light');
                            }
                        });
                    </script>
                    {{-- <div class="dropdown">
                        <a href="#" id="topbarUserDropdown" class="user-dropdown d-flex align-items-center dropend dropdown-toggle" data-bs-toggle="dropdown" aria-expanded="false">
                            <div class="avatar avatar-md2">
                                <button class="dropdown-btn">
                                    @if ($currentLanguage)
                                        <img src="{{ $currentLanguage->image }}" alt="{{ $currentLanguage->name }}" id="current-flag" class="flag">
                                        <span id="current-language">{{ $currentLanguage->code }}</span>
                                    @else
                                    <img src="{{ $defaultLanguage->image }}" alt="{{ $defaultLanguage->name }}" alt="default-language" id="current-flag" class="flag">
                                    <span id="current-language">{{ $defaultLanguage->code }}</span>
                                    @endif
                                    <span class="arrow">&#9662;</span>
                                </button>
                            </div>
                            <div class="text"></div>
                        </a>
                        <ul class="dropdown-menu dropdown-menu-end topbarUserDropdown" aria-labelledby="topbarUserDropdown">
                            @foreach ($languages as $language)
                                <li>
                                    <a class="dropdown-item" href="{{ route('language.set-current', $language->code) }}">
                                        <img src="{{ $language->image }}" alt="{{ $language->name }}" class="flag"> {{ $language->name }}
                                    </a>
                                </li>
                            @endforeach
                        </ul>
                    </div> --}}
                    &nbsp;&nbsp;
                    @php
                        $authUser = Auth::user();
                        $storeProfile = $authUser?->store;
                        $fallbackAvatar = url('assets/images/faces/2.jpg');
                        $avatarUrl = $storeProfile && filled($storeProfile->logo_path)
                            ? $storeProfile->logo_path
                            : ($authUser && filled($authUser->profile) ? $authUser->profile : $fallbackAvatar);
                        $displayName = $storeProfile && filled($storeProfile->name)
                            ? $storeProfile->name
                            : ($authUser?->name ?? __('Guest'));
                        $loginUrl = \Illuminate\Support\Facades\Route::has('login') ? route('login') : url('/');
                    @endphp

                    @if($authUser)
                        <div class="dropdown">
                            <a href="#" id="topbarUserDropdown"
                               class="user-dropdown d-flex align-items-center dropend dropdown-toggle"
                               data-bs-toggle="dropdown" aria-expanded="false">
                                <div class="avatar avatar-md2">
                                    <img src="{{ $avatarUrl }}" alt="{{ $displayName }}">
                                </div>
                                <div class="text">
                                    <h6 class="user-dropdown-name">{{ $displayName }}</h6>
                                    <p class="user-dropdown-status text-sm text-muted"></p>
                                </div>
                            </a>
                            <ul class="dropdown-menu dropdown-menu-end topbarUserDropdown" aria-labelledby="topbarUserDropdown">
                                <li><a class="dropdown-item" href="{{ route('change-password.index') }}"><i class="icon-mid bi bi-gear me-2"></i>{{__("Change Password")}}</a></li>
                                <li><a class="dropdown-item" href="{{ route('change-profile.index') }}"><i class="icon-mid bi bi-person me-2"></i>{{__("Change Profile")}}</a></li>
                                <li><a class="dropdown-item" href="{{ route('logout') }} " onclick="event.preventDefault(); document.getElementById('logout-form').submit();"><i class="icon-mid bi bi-box-arrow-left me-2"></i> {{__("Logout")}}</a></li>
                                <form id="logout-form" action="{{ route('logout') }}" method="POST" class="d-none">
                                    {{ csrf_field() }}
                                </form>
                            </ul>
                        </div>
                    @else
                        <div class="d-flex align-items-center">
                            <div class="avatar avatar-md2 me-2">
                                <img src="{{ $avatarUrl }}" alt="Guest" class="opacity-75">
                            </div>
                            <a href="{{ $loginUrl }}" class="btn btn-sm btn-outline-primary">
                                <i class="bi bi-box-arrow-in-right me-1"></i>{{ __('Login') }}
                            </a>
                        </div>
                    @endif
                </div>
            </div>
        </div>
    </nav>
</header>
