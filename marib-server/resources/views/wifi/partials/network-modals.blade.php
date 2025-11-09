@php
    use App\Enums\Wifi\WifiNetworkStatus;
    use App\Enums\Wifi\WifiReportStatus;
    use App\Enums\Wifi\WifiCodeBatchStatus;

    $networkStatusOptions = [
        WifiNetworkStatus::ACTIVE->value => __('ظ†ط´ط·'),
        WifiNetworkStatus::INACTIVE->value => __('ظ…طھظˆظ‚ظپ ظ…ط¤ظ‚طھظ‹ط§'),
        WifiNetworkStatus::SUSPENDED->value => __('ظ…ط¹ظ„ظ‘ظ‚ ظ„ظ„طھط­ظ‚ظٹظ‚'),
    ];

    $reportStatusOptions = [
        WifiReportStatus::OPEN->value => __('ظ…ظپطھظˆط­'),
        WifiReportStatus::INVESTIGATING->value => __('ظ‚ظٹط¯ ط§ظ„ظ…طھط§ط¨ط¹ط©'),
        WifiReportStatus::RESOLVED->value => __('ظ…ط؛ظ„ظ‚ - طھظ… ط§ظ„ط­ظ„'),
        WifiReportStatus::DISMISSED->value => __('ظ…ط؛ظ„ظ‚ - ظ…ط±ظپظˆط¶'),
    ];

    $batchStatusOptions = [
        WifiCodeBatchStatus::UPLOADED->value => __('ظ…ط±ظپظˆط¹'),
        WifiCodeBatchStatus::VALIDATED->value => __('ظ‚ظٹط¯ ط§ظ„ظ…ط±ط§ط¬ط¹ط©'),
        WifiCodeBatchStatus::ACTIVE->value => __('ظ…ظپط¹ظ„'),
        WifiCodeBatchStatus::ARCHIVED->value => __('ظ…ط¤ط±ط´ظپ'),
    ];
@endphp

<div class="modal fade" id="wifiNetworkDetailsModal" tabindex="-1" aria-hidden="true" data-wifi-network-modal>
    <div class="modal-dialog modal-xl modal-dialog-scrollable modal-dialog-centered">
        <div class="modal-content shadow-lg border-0">
            <div class="modal-header border-0 pb-0">
                <div>
                    <h5 class="modal-title fw-semibold mb-1" data-network-name></h5>
                    <p class="text-muted mb-0" data-network-subtitle>{{ __('ط¹ط±ط¶ طھظپط§طµظٹظ„ ط§ظ„ط´ط¨ظƒط© ظˆط§ظ„ط¹ظ…ظ„ظٹط§طھ ط§ظ„ظ…طھط§ط­ط©.') }}</p>
                </div>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="{{ __('ط¥ط؛ظ„ط§ظ‚') }}"></button>
            </div>
            <div class="modal-body pt-3">
                <div class="row g-4">
                    <div class="col-lg-4">
                        <div class="wifi-network-card h-100">
                            <div class="wifi-network-card__logo-wrapper mb-3">
                                <img src="{{ asset('assets/images/no_image_available.png') }}" alt="logo" class="wifi-network-card__logo" data-network-logo>
                            </div>
                            <div class="d-flex flex-column gap-2">
                                <div>
                                    <span class="text-muted small d-block">{{ __('ط§ظ„ط­ط§ظ„ط© ط§ظ„ط­ط§ظ„ظٹط©') }}</span>
                                    <span class="badge rounded-pill bg-light text-dark fw-semibold" data-network-status-label>â€”</span>
                                </div>
                                <div>
                                    <span class="text-muted small d-block">{{ __('ط§ظ„ط¹ظ…ظˆظ„ط© ط§ظ„ظ…ط¹طھظ…ط¯ط©') }}</span>
                                    <span class="fw-semibold" data-network-commission>â€”</span>
                                </div>
                                <div>
                                    <span class="text-muted small d-block">{{ __('ط§ظ„ط¹ظ†ظˆط§ظ†') }}</span>
                                    <span data-network-address>â€”</span>
                                </div>
                                <div>
                                    <span class="text-muted small d-block">{{ __('ط¢ط®ط± طھط­ط¯ظٹط«') }}</span>
                                    <span data-network-updated-at>â€”</span>
                                </div>
                            </div>
                        </div>
                    </div>
                    <div class="col-lg-8">
                        <div class="row g-3">
                            <div class="col-md-6">
                                <div class="wifi-network-info h-100">
                                    <h6 class="wifi-network-info__title">{{ __('ط¥ط­طµط§ط،ط§طھ ط§ظ„ط£ط¯ط§ط،') }}</h6>
                                    <ul class="wifi-network-info__list" data-network-stats>
                                        <li class="wifi-network-info__item">
                                            <span>{{ __('ط§ظ„ط®ط·ط· ط§ظ„ظ†ط´ط·ط©') }}</span>
                                            <span data-network-active-plans>â€”</span>
                                        </li>
                                        <li class="wifi-network-info__item">
                                            <span>{{ __('ط§ظ„ط£ظƒظˆط§ط¯ ط§ظ„ظ…ط±ظپظˆط¹ط©') }}</span>
                                            <span data-network-total-codes>â€”</span>
                                        </li>
                                        <li class="wifi-network-info__item">
                                            <span>{{ __('ط§ظ„ط£ظƒظˆط§ط¯ ط§ظ„ظ…طھط§ط­ط©') }}</span>
                                            <span data-network-available-codes>â€”</span>
                                        </li>
                                        <li class="wifi-network-info__item">
                                            <span>{{ __('ط§ظ„ط£ظƒظˆط§ط¯ ط§ظ„ظ…ط¨ط§ط¹ط©') }}</span>
                                            <span data-network-sold-codes>â€”</span>
                                        </li>
                                    </ul>
                                </div>
                            </div>
                            <div class="col-md-6">
                                <div class="wifi-network-info h-100">
                                    <h6 class="wifi-network-info__title">{{ __('ط¨ظٹط§ظ†ط§طھ ط§ظ„ط§طھطµط§ظ„') }}</h6>
                                    <ul class="wifi-network-info__list" data-network-contacts>
                                        <li class="wifi-network-info__item">
                                            <span>{{ __('ط§ط³ظ… ط§ظ„ظ…ط§ظ„ظƒ') }}</span>
                                            <span data-network-owner>â€”</span>
                                        </li>
                                        <li class="wifi-network-info__item">
                                            <span>{{ __('ط§ظ„ط¨ط±ظٹط¯ ط§ظ„ط¥ظ„ظƒطھط±ظˆظ†ظٹ') }}</span>
                                            <span data-network-owner-email>â€”</span>
                                        </li>
                                        <li class="wifi-network-info__item">
                                            <span>{{ __('ط§ظ„ظ‡ط§طھظپ') }}</span>
                                            <span data-network-owner-phone>â€”</span>
                                        </li>
                                        <li class="wifi-network-info__item">
                                            <span>{{ __('ظ‚ظ†ط§ط© ط§ظ„ط¯ط¹ظ…') }}</span>
                                            <span data-network-support-channel>â€”</span>
                                        </li>
                                    </ul>
                                </div>
                            </div>
<div class="col-12">
                                <div class="wifi-network-plans" data-network-plans>
                                    <div class="d-flex justify-content-between align-items-center mb-2">
                                        <h6 class="wifi-network-info__title mb-0">{{ __('ط§ظ„ط®ط·ط· ط§ظ„ظ…طھط§ط­ط©') }}</h6>
                                        <span class="badge bg-light text-dark" data-network-plans-count>0</span>
                                    </div>
                                    <div class="wifi-network-plans__list" data-network-plans-container>
                                        <p class="text-muted mb-0">{{ __('ط³ظٹطھظ… طھط­ظ…ظٹظ„ ط§ظ„ط®ط·ط· ط§ظ„ظ…ط±طھط¨ط·ط© ط¹ظ†ط¯ ظپطھط­ ط§ظ„ظ†ط§ظپط°ط©.') }}</p>
                                    </div>
                                </div>
<div class="col-12">
                                <div class="wifi-network-plans" data-network-batches>
                                    <div class="d-flex justify-content-between align-items-center mb-2">
                                        <h6 class="wifi-network-info__title mb-0">{{ __('ط¯ظپط¹ط§طھ ط§ظ„ط£ظƒظˆط§ط¯ ط§ظ„ط£ط®ظٹط±ط©') }}</h6>
                                        <span class="badge bg-light text-dark" data-network-batches-count>0</span>
                                    </div>
                                    <div class="wifi-network-plans__list" data-network-batches-container>
                                        <p class="text-muted mb-0">{{ __('ظ„ظ… ظٹطھظ… طھط­ظ…ظٹظ„ ط£ظٹ ط¯ظپط¹ط§طھ ط¨ط¹ط¯.') }}</p>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            <div class="modal-footer border-0 justify-content-between flex-wrap gap-2">
                <div class="d-flex gap-2">
                    <button type="button" class="btn btn-outline-secondary" data-action="refresh-network-details">
                        <i class="bi bi-arrow-repeat"></i> {{ __('طھط­ط¯ظٹط« ط§ظ„ط¨ظٹط§ظ†ط§طھ') }}
                    </button>
                    <button type="button" class="btn btn-outline-primary" data-action="open-network-batches">
                        <i class="bi bi-collection"></i> {{ __('ط¥ط¯ط§ط±ط© ط§ظ„ط¯ظپط¹ط§طھ') }}
                    </button>
                </div>
                <div class="d-flex gap-2">
                    <button type="button" class="btn btn-warning" data-action="open-network-commission">
                        <i class="bi bi-cash-stack"></i> {{ __('طھط¹ط¯ظٹظ„ ط§ظ„ط¹ظ…ظˆظ„ط©') }}
                    </button>
                    <button type="button" class="btn btn-primary" data-action="open-network-status">
                        <i class="bi bi-shield-check"></i> {{ __('طھط­ط¯ظٹط« ط§ظ„ط­ط§ظ„ط©') }}
                    </button>
                </div>
            </div>
        </div>
    </div>
</div>

<div class="modal fade" id="wifiNetworkStatusModal" tabindex="-1" aria-hidden="true" data-wifi-status-modal>
    <div class="modal-dialog modal-md modal-dialog-centered">
        <div class="modal-content border-0 shadow">
            <div class="modal-header border-0">
                <h5 class="modal-title fw-semibold">{{ __('طھط­ط¯ظٹط« ط­ط§ظ„ط© ط§ظ„ط´ط¨ظƒط©') }}</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="{{ __('ط¥ط؛ظ„ط§ظ‚') }}"></button>
            </div>
            <form method="post" class="needs-validation" novalidate data-network-status-form>
                @csrf
                <input type="hidden" name="_method" value="patch">
                <div class="modal-body">
                    <div class="mb-3">
                        <label for="wifi_network_status" class="form-label">{{ __('ط§ظ„ط­ط§ظ„ط© ط§ظ„ط¬ط¯ظٹط¯ط©') }}</label>
                        <select id="wifi_network_status" name="status" class="form-select" required>
                            @foreach($networkStatusOptions as $value => $label)
                                <option value="{{ $value }}">{{ $label }}</option>
                            @endforeach
                        </select>
                    </div>
                    <div class="mb-0">
                        <label for="wifi_network_reason" class="form-label">{{ __('ط³ط¨ط¨ ط§ظ„طھط¹ط¯ظٹظ„ (ط§ط®طھظٹط§ط±ظٹ)') }}</label>
                        <textarea id="wifi_network_reason" name="reason" class="form-control" rows="3" maxlength="250" placeholder="{{ __('ط§ظƒطھط¨ ظ…ظ„ط§ط­ط¸ط§طھظƒ ظ„ظ„ظ…ط§ظ„ظƒ ط£ظˆ ظپط±ظٹظ‚ ط§ظ„ط¯ط¹ظ…') }}"></textarea>
                    </div>
                    <div class="form-text text-muted mt-2" data-network-status-feedback></div>
                </div>
                <div class="modal-footer border-0">
                    <button type="button" class="btn btn-light" data-bs-dismiss="modal">{{ __('ط¥ظ„ط؛ط§ط،') }}</button>
                    <button type="submit" class="btn btn-primary">
                        <i class="bi bi-save"></i> {{ __('ط­ظپط¸ ط§ظ„ط­ط§ظ„ط©') }}
                    </button>
                </div>
            </form>
        </div>
    </div>
</div>

<div class="modal fade" id="wifiNetworkCommissionModal" tabindex="-1" aria-hidden="true" data-wifi-commission-modal>
    <div class="modal-dialog modal-md modal-dialog-centered">
        <div class="modal-content border-0 shadow">
            <div class="modal-header border-0">
                <h5 class="modal-title fw-semibold">{{ __('طھط¹ط¯ظٹظ„ ط¹ظ…ظˆظ„ط© ط§ظ„ط´ط¨ظƒط©') }}</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="{{ __('ط¥ط؛ظ„ط§ظ‚') }}"></button>
            </div>
            <form method="post" class="needs-validation" novalidate data-network-commission-form>
                @csrf
                <input type="hidden" name="_method" value="patch">
                <div class="modal-body">
                    <div class="mb-3">
                        <label for="wifi_network_commission" class="form-label">{{ __('ط§ظ„ظ†ط³ط¨ط© ط§ظ„ظ…ط¦ظˆظٹط©') }}</label>
                        <div class="input-group">
                            <input type="number" step="0.01" min="0" max="50" id="wifi_network_commission" name="commission_rate" class="form-control" required placeholder="{{ __('ط£ط¯ط®ظ„ ظ†ط³ط¨ط© ط§ظ„ط¹ظ…ظˆظ„ط©') }}">
                            <span class="input-group-text">%</span>
                        </div>
                        <div class="form-text">{{ __('ظٹطھظ… ط§ط­طھط³ط§ط¨ ط§ظ„ط¹ظ…ظˆظ„ط© ظ…ظ† ظ‚ظٹظ…ط© ط§ظ„ظ…ط¨ظٹط¹ط§طھ ط§ظ„ظ†ظ‡ط§ط¦ظٹط©طŒ ط§ظ„ط­ط¯ ط§ظ„ط£ظ‚طµظ‰ 50%.') }}</div>
                    </div>
                    <div class="form-text text-muted" data-network-commission-feedback></div>
                </div>
                <div class="modal-footer border-0">
                    <button type="button" class="btn btn-light" data-bs-dismiss="modal">{{ __('ط¥ط؛ظ„ط§ظ‚') }}</button>
                    <button type="submit" class="btn btn-success">
                        <i class="bi bi-check2-circle"></i> {{ __('طھط­ط¯ظٹط« ط§ظ„ط¹ظ…ظˆظ„ط©') }}
                    </button>
                </div>
            </form>
        </div>
    </div>
</div>

<div class="modal fade" id="wifiNetworkBatchesModal" tabindex="-1" aria-hidden="true" data-wifi-batches-modal>
    <div class="modal-dialog modal-lg modal-dialog-scrollable modal-dialog-centered">
        <div class="modal-content border-0 shadow">
            <div class="modal-header border-0">
                <div>
                    <h5 class="modal-title fw-semibold">{{ __('ط¯ظپط¹ط§طھ ط§ظ„ط£ظƒظˆط§ط¯ ط§ظ„ظ…ط±طھط¨ط·ط©') }}</h5>
                    <p class="text-muted mb-0" data-network-batches-subtitle>{{ __('طھط­ظƒظ… ط¨ط¯ظپط¹ط§طھ ط§ظ„ط£ظƒظˆط§ط¯ ط§ظ„ظ…ط±ظپظˆط¹ط© ظ„ظƒظ„ ط®ط·ط©.') }}</p>
                </div>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="{{ __('ط¥ط؛ظ„ط§ظ‚') }}"></button>
            </div>
            <div class="modal-body">
                <div class="d-flex justify-content-between align-items-center flex-wrap gap-2 mb-3">
                    <div class="btn-group" role="group">
                        <button type="button" class="btn btn-outline-primary" data-action="refresh-batches">
                            <i class="bi bi-arrow-clockwise"></i> {{ __('طھط­ط¯ظٹط«') }}
                        </button>
                        <a href="{{ route('wifi.create') }}" class="btn btn-primary">
                            <i class="bi bi-upload"></i> {{ __('ط±ظپط¹ ط¯ظپط¹ط© ط¬ط¯ظٹط¯ط©') }}
                        </a>
                    </div>
                    <div class="d-flex align-items-center gap-2">
                        <label for="wifi_batch_status_filter" class="form-label mb-0">{{ __('ط§ظ„ط­ط§ظ„ط©') }}</label>
                        <select id="wifi_batch_status_filter" class="form-select form-select-sm" data-batch-status-filter>
                            <option value="">{{ __('ط§ظ„ظƒظ„') }}</option>
                            @foreach($batchStatusOptions as $value => $label)
                                <option value="{{ $value }}">{{ $label }}</option>
                            @endforeach
                        </select>
                    </div>
                </div>
                <div class="table-responsive">
                    <table id="wifi-network-batches-table" class="table table-hover align-middle"
                           data-toggle="table"
                           data-search="false"
                           data-pagination="true"
                           data-page-size="5"
                           data-side-pagination="client"
                           data-mobile-responsive="true"
                           data-locale="{{ app()->getLocale() }}"
                           data-empty-text="{{ __('ظ„ط§ طھظˆط¬ط¯ ط¯ظپط¹ط§طھ ظ…ط³ط¬ظ„ط© ظ„ظ‡ط°ظ‡ ط§ظ„ط´ط¨ظƒط© ط¨ط¹ط¯.') }}">
                        <thead class="table-light">
                        <tr>
                            <th data-field="label">{{ __('ط§ظ„ظˆط³ظ…') }}</th>
                            <th data-field="plan">{{ __('ط§ظ„ط®ط·ط©') }}</th>
                            <th data-field="status" data-formatter="MaribWifiAdminTables.formatBatchStatus">{{ __('ط§ظ„ط­ط§ظ„ط©') }}</th>
                            <th data-field="available_codes">{{ __('ط§ظ„ظ…طھط§ط­') }}</th>
                            <th data-field="total_codes">{{ __('ط§ظ„ط¥ط¬ظ…ط§ظ„ظٹ') }}</th>
                            <th data-field="created_at" data-formatter="MaribWifiAdminTables.formatDate">{{ __('طھط§ط±ظٹط® ط§ظ„ط±ظپط¹') }}</th>
                            <th data-field="actions" data-formatter="MaribWifiAdminTables.formatBatchActions" data-events="MaribWifiAdminTables.batchActionEvents" data-align="center">{{ __('ط¥ط¬ط±ط§ط،ط§طھ') }}</th>
                        </tr>
                        </thead>
                    </table>
                </div>
            </div>
            <div class="modal-footer border-0">
                <button type="button" class="btn btn-light" data-bs-dismiss="modal">{{ __('ط¥ط؛ظ„ط§ظ‚ ط§ظ„ظ†ط§ظپط°ط©') }}</button>
            </div>
        </div>
    </div>
</div>

