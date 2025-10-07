@extends('layouts.main')

@section('title')
    {{ __('Marketing Automation & Notifications') }}
@endsection

@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>

                <p class="text-muted mb-0">{{ __('Design, target, and measure campaigns across your customer base.') }}</p>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first d-flex justify-content-md-end align-items-start">
                <div class="d-flex gap-2">
                    <span class="badge bg-primary">{{ __('Automation') }}</span>
                    <span class="badge bg-success">{{ __('Behavioural Segments') }}</span>
                    <span class="badge bg-info">{{ __('Real-time Reporting') }}</span>
                </div>



            </div>

        </div>
    </div>
@endsection

@section('content')
    <div class="row">
        <section class="section">





            <div class="card">
                <div class="card-body">
                    <ul class="nav nav-tabs" id="notificationTabs" role="tablist">
                        <li class="nav-item" role="presentation">
                            <button class="nav-link active" id="broadcast-tab" data-bs-toggle="tab" data-bs-target="#tab-broadcast" type="button" role="tab">
                                <i class="bi bi-send"></i> {{ __('Direct Broadcast') }}
                            </button>
                        </li>
                        <li class="nav-item" role="presentation">
                            <button class="nav-link" id="campaigns-tab" data-bs-toggle="tab" data-bs-target="#tab-campaigns" type="button" role="tab">
                                <i class="bi bi-bullseye"></i> {{ __('Campaign Builder') }}
                            </button>
                        </li>
                        <li class="nav-item" role="presentation">
                            <button class="nav-link" id="automation-tab" data-bs-toggle="tab" data-bs-target="#tab-automation" type="button" role="tab">
                                <i class="bi bi-lightning-charge"></i> {{ __('Automation & Events') }}
                            </button>
                        </li>
                        <li class="nav-item" role="presentation">
                            <button class="nav-link" id="reports-tab" data-bs-toggle="tab" data-bs-target="#tab-reports" type="button" role="tab">
                                <i class="bi bi-graph-up-arrow"></i> {{ __('Reports & Performance') }}
                            </button>
                        </li>
                    </ul>

                    <div class="tab-content pt-4" id="notificationTabsContent">
                        <div class="tab-pane fade show active" id="tab-broadcast" role="tabpanel" aria-labelledby="broadcast-tab">
                            @can('notification-create')
                                <div class="row g-4">
                                    <div class="col-lg-6">
                                        <div class="card border shadow-sm h-100">
                                            <div class="card-header bg-light">
                                                <h5 class="mb-0">{{ __('Quick Broadcast') }}</h5>
                                                <small class="text-muted">{{ __('Send an immediate notification to a targeted audience.') }}</small>
                                            </div>
                                            <div class="card-body">
                                                <form action="{{ route('notification.store') }}" class="create-form needs-validation" method="post" data-parsley-validate enctype="multipart/form-data">
                                                    @csrf
                                                    <textarea id="user_id" name="user_id" style="visibility: hidden;position: absolute;" aria-label="user_id"></textarea>
                                                    <div class="mb-3">
                                                        <label for="send_to" class="form-label">{{ __('Select Audience') }}</label>
                                                        <select id="send_to" name="send_to" class="form-control w-100 select2" required>
                                                            <option value="all">{{ __('الكل') }}</option>
                                                            <option value="selected">{{ __('المختار فقط') }}</option>
                                                            <option value="individual">{{ __('فردي') }}</option>
                                                            <option value="business">{{ __('تجاري') }}</option>
                                                            <option value="real_estate">{{ __('عقاري') }}</option>
                                                        </select>
                                                    </div>

                                                    <div class="mb-3">
                                                        <label for="title" class="form-label">{{ __('Title') }}</label> <span class="text-danger">*</span>
                                                        <input name="title" id="title" type="text" class="form-control" placeholder="{{ __('Title') }}" required>
                                                    </div>

                                                    <div class="mb-3">
                                                        <label for="message" class="form-label">{{ __('Message') }}</label> <span class="text-danger">*</span>
                                                        <textarea id="message" name="message" class="form-control" placeholder="{{ __('Message') }}" rows="4" required></textarea>
                                                    </div>

                                                    <div class="mb-3 form-check">
                                                        <input id="include_image" name="include_image" type="checkbox" class="form-check-input">
                                                        <label for="include_image" class="form-check-label">{{ __('Include Image') }}</label>
                                                    </div>

                                                    <div class="mb-3" id="show_image" style="display: none">
                                                        <label class="form-label" for="file">{{ __('Image') }}</label>
                                                        <input id="file" name="file" type="file" accept="image/*" class="form-control">
                                                        <p style="display: none" id="img_error_msg" class="badge rounded-pill bg-danger"></p>
                                                    </div>

                                                    <div class="mb-3">
                                                        <label for="item_id" class="form-label">{{ __('Item') }}</label>
                                                        <select name="item_id" class="select2 form-select form-control-sm" data-parsley-minselect="1" id="item_id">
                                                            <option value=""> {{ __('Select Item') }} </option>
                                                            @foreach ($item_list as $row)
                                                                <option value="{{ $row->id }}" data-parametertypes='{{ $row->name }}'>{{ $row->name }}</option>
                                                            @endforeach
                                                        </select>
                                                    </div>

                                                    <div class="d-flex justify-content-end">
                                                        <button class="btn btn-primary" type="submit" name="submit">{{ __('Submit') }}</button>
                                                    </div>
                                                </form>
                                            </div>


                                        </div>
                                    </div>



                                    <div class="col-lg-6">
                                        <div class="card border shadow-sm">
                                            <div class="card-header bg-light d-flex justify-content-between align-items-center">
                                                <div>
                                                    <h5 class="mb-0">{{ __('User Explorer') }}</h5>
                                                    <small class="text-muted">{{ __('Filter & select recipients to build a custom broadcast list.') }}</small>
                                                </div>
                                            </div>
                                            <div class="card-body">
                                                <table class="table table-borderless table-striped" aria-describedby="userExplorer"
                                                       id="user_notification_list" data-toggle="table" data-url="{{ route('customer.list') }}"
                                                       data-click-to-select="true" data-side-pagination="server" data-pagination="true"
                                                       data-page-list="[5, 10, 20, 50, 100, 200]" data-search="true"
                                                       data-toolbar="#toolbar" data-show-columns="true" data-show-refresh="true"
                                                       data-fixed-columns="true" data-fixed-number="1" data-fixed-right-number="1"
                                                       data-trim-on-search="false" data-responsive="true" data-sort-name="id"
                                                       data-sort-order="desc" data-pagination-successively-size="3"
                                                       data-escape="true"
                                                       data-query-params="notificationUserList"
                                                       data-mobile-responsive="true">
                                                    <thead class="thead-dark">
                                                    <tr>
                                                        <th scope="col" data-field="state" data-checkbox="true"></th>
                                                        <th scope="col" data-field="id" data-sortable="true">{{ __('ID') }}</th>
                                                        <th scope="col" data-field="name" data-sortable="true">{{ __('Name') }}</th>
                                                        <th scope="col" data-field="mobile" data-sortable="true">{{ __('Number') }}</th>
                                                    </tr>
                                                    </thead>
                                                </table>
                                            </div>


                                        </div>
                                    </div>
                                </div>
                            @endcan


                            <div class="card border mt-4 shadow-sm">
                                <div class="card-header bg-light d-flex justify-content-between align-items-center">
                                    <h5 class="mb-0">{{ __('Notification History') }}</h5>
                                    <div id="toolbar" class="d-flex gap-2">
                                        @can('notification-delete')
                                            <a href="{{ route('notification.batch.delete') }}" class="btn btn-danger btn-sm btn-icon text-white" id="delete_multiple" title="{{ __('Delete Notification') }}"><em class='fa fa-trash'></em></a>
                                        @endcan


                                    </div>



                                                                    </div>
                                <div class="card-body">
                                    <table aria-describedby="notificationHistory" class='table-striped' id="table_list" data-toggle="table"
                                           data-url="{{ route('notification.show',1) }}" data-click-to-select="true"
                                           data-side-pagination="server" data-pagination="true"
                                           data-page-list="[5, 10, 20, 50, 100, 200]" data-search="true" data-toolbar="#toolbar"
                                           data-show-columns="true" data-show-refresh="true" data-fixed-columns="true"
                                           data-fixed-number="1" data-fixed-right-number="1" data-trim-on-search="false"
                                           data-escape="true"
                                           data-responsive="true" data-sort-name="id" data-sort-order="desc"
                                           data-pagination-successively-size="3" data-show-export="true" data-export-options='{"fileName": "notification-history","ignoreColumn": ["operate"]}' data-export-types="['pdf','json', 'xml', 'csv', 'txt', 'sql', 'doc', 'excel']">
                                        <thead>
                                        <tr>
                                            @can('notification-delete')
                                                <th scope="col" data-field="state" data-checkbox="true"></th>
                                            @endcan
                                            <th scope="col" data-field="id" data-sortable="true">{{ __('ID') }}</th>
                                            <th scope="col" data-field="title" data-sortable="true">{{ __('Title') }}</th>
                                            <th scope="col" data-field="message" data-sortable="true">{{ __('Message') }}</th>
                                            <th scope="col" data-field="image" data-formatter="imageFormatter">{{ __('Image') }}</th>
                                            <th scope="col" data-field="send_to" data-sortable="true">{{ __('Send To') }}</th>
                                            @can('notification-delete')
                                                <th scope="col" data-field="operate" data-escape="false">{{ __('Action') }}</th>
                                            @endcan
                                        </tr>
                                        </thead>
                                    </table>
                                </div>
                            </div>
                        </div>

                        <div class="tab-pane fade" id="tab-campaigns" role="tabpanel" aria-labelledby="campaigns-tab">
                            <div class="row g-4">
                                @can('notification-create')
                                    <div class="col-lg-6">
                                        <div class="card border shadow-sm h-100">
                                            <div class="card-header bg-light">
                                                <h5 class="mb-0">{{ __('Create Campaign') }}</h5>
                                                <small class="text-muted">{{ __('Define message, targeting rules, and trigger logic for automated marketing pushes.') }}</small>
                                            </div>
                                            <div class="card-body">
                                                <form
                                                    id="campaign-builder-form"
                                                    action="{{ route('notification.campaigns.store') }}"
                                                    method="post"
                                                    class="create-form needs-validation"
                                                    data-parsley-validate
                                                    data-success-function="handleCampaignCreated"
                                                >



                                                    @csrf
                                                    <div class="mb-3">
                                                        <label class="form-label" for="campaign-name">{{ __('Campaign Name') }}</label>
                                                        <input type="text" id="campaign-name" name="name" class="form-control" placeholder="{{ __('Loyalty reactivation – Ramadan') }}" required>
                                                    </div>

                                                    <div class="mb-3">
                                                        <label class="form-label" for="campaign-title">{{ __('Notification Title') }}</label>
                                                        <input type="text" id="campaign-title" name="notification_title" class="form-control" required>
                                                    </div>

                                                    <div class="mb-3">
                                                        <label class="form-label" for="campaign-body">{{ __('Notification Body') }}</label>
                                                        <textarea id="campaign-body" name="notification_body" class="form-control" rows="4" required></textarea>
                                                    </div>


                                                    <div class="row g-3">
                                                        <div class="col-md-6">
                                                            <label class="form-label" for="campaign-cta-label">{{ __('CTA Label') }}</label>
                                                            <input type="text" id="campaign-cta-label" name="cta_label" class="form-control" placeholder="{{ __('Shop now') }}">
                                                        </div>
                                                        <div class="col-md-6">
                                                            <label class="form-label" for="campaign-cta-destination">{{ __('CTA Destination (Deep link / screen)') }}</label>
                                                            <input type="text" id="campaign-cta-destination" name="cta_destination" class="form-control" placeholder="app://offers">
                                                        </div>
                                                    </div>

                                                    <div class="row g-3 mt-1">
                                                        <div class="col-md-6">
                                                            <label class="form-label" for="trigger-type">{{ __('Trigger Type') }}</label>
                                                            <select name="trigger_type" id="trigger-type" class="form-select">
                                                                <option value="manual">{{ __('Manual / On demand') }}</option>
                                                                <option value="scheduled">{{ __('Scheduled') }}</option>
                                                                <option value="event">{{ __('Event driven') }}</option>
                                                            </select>
                                                        </div>
                                                        <div class="col-md-6 scheduled-only d-none">
                                                            <label class="form-label" for="scheduled_at">{{ __('Schedule At') }}</label>
                                                            <input type="datetime-local" name="scheduled_at" id="scheduled_at" class="form-control">
                                                        </div>
                                                    </div>

                                                    <div class="row g-3 mt-1 event-only d-none">
                                                        <div class="col-md-12">
                                                            <label class="form-label" for="event_key">{{ __('Automation Event Key') }}</label>
                                                            <input type="text" name="event_key" id="event_key" class="form-control" placeholder="user.inactive">
                                                            <small class="text-muted">{{ __('Matches keys configured under Automation & Events tab.') }}</small>
                                                        </div>
                                                    </div>

                                                    <div class="mt-3">
                                                        <label class="form-label">{{ __('Segments & Behavioural Filters') }}</label>
                                                        <div id="campaign-segments"></div>
                                                        <button class="btn btn-outline-primary btn-sm mt-2" type="button" id="add-segment">
                                                            <i class="bi bi-plus-circle"></i> {{ __('Add Segment') }}
                                                        </button>
                                                    </div>

                                                    <div class="form-check mt-3">
                                                        <input class="form-check-input" type="checkbox" value="1" id="dispatch_now" name="dispatch_now">
                                                        <label class="form-check-label" for="dispatch_now">
                                                            {{ __('Dispatch immediately after saving (manual trigger only)') }}
                                                        </label>
                                                    </div>

                                                    <div class="d-flex justify-content-end mt-4">
                                                        <button type="submit" class="btn btn-success">
                                                            <i class="bi bi-cloud-arrow-up"></i> {{ __('Save Campaign') }}
                                                        </button>
                                                    </div>
                                                </form>




                                            </div>
                                        </div>
                                    </div>

                                @endcan





                                <div class="col-lg-6">
                                    <div class="card border shadow-sm h-100">
                                        <div class="card-header bg-light d-flex justify-content-between align-items-center">
                                            <div>
                                                <h5 class="mb-0">{{ __('Active Campaigns') }}</h5>
                                                <small class="text-muted">{{ __('Monitor automation status, schedules, and linked segments.') }}</small>
                                            </div>
                                        </div>
                                        <div class="card-body">
                                            <div class="table-responsive">

                                                <table class="table table-striped align-middle" id="campaigns-table" data-can-dispatch="{{ auth()->user()->can('notification-create') ? '1' : '0' }}">
                                                    
                                                <thead>
                                                    <tr>
                                                        <th>{{ __('Name') }}</th>
                                                        <th>{{ __('Trigger') }}</th>
                                                        <th>{{ __('Status') }}</th>
                                                        <th>{{ __('Segments') }}</th>
                                                        <th>{{ __('Next Run') }}</th>
                                                        <th class="text-end">{{ __('Actions') }}</th>
                                                    </tr>
                                                    </thead>
                                                
                                                    <tbody id="campaigns-list" data-dispatch-url-template="{{ route('notification.campaigns.send', ['campaign' => '__CAMPAIGN_ID__']) }}">



                                                    @forelse($campaigns as $campaign)
                                                        <tr>
                                                            <td>
                                                                <strong>{{ $campaign->name }}</strong>
                                                                <div class="small text-muted">{{ \Illuminate\Support\Str::limit($campaign->notification_body, 60) }}</div>
                                                            </td>
                                                            <td><span class="badge bg-secondary text-uppercase">{{ __($campaign->trigger_type) }}</span></td>
                                                            <td>
                                                                <span class="badge {{ $campaign->status === 'active' ? 'bg-success' : ($campaign->status === 'scheduled' ? 'bg-info' : 'bg-secondary') }} text-uppercase">{{ __($campaign->status) }}</span>
                                                            </td>
                                                            <td>
                                                                <div class="d-flex flex-column gap-1">
                                                                    @forelse($campaign->segments as $segment)
                                                                        <span class="badge bg-light text-dark border">{{ $segment->name }} ({{ $segment->estimated_size ?? 0 }})</span>
                                                                    @empty
                                                                        <span class="badge bg-light text-muted">{{ __('All users (no segment)') }}</span>
                                                                    @endforelse
                                                                </div>
                                                            </td>
                                                            <td>
                                                                @if($campaign->scheduled_at)
                                                                    {{ $campaign->scheduled_at->format('Y-m-d H:i') }}
                                                                @else
                                                                    <span class="text-muted">—</span>
                                                                @endif
                                                            </td>
                                                            <td class="text-end">
                                                                @can('notification-create')
                                                                    <div class="btn-group btn-group-sm">
                                                                            <form action="{{ route('notification.campaigns.send', $campaign) }}" method="post" class="d-inline">
                                                                            @csrf
                                                                            <button type="submit" class="btn btn-outline-primary" title="{{ __('Run Now') }}">
                                                                                <i class="bi bi-play"></i>
                                                                            </button>
                                                                        </form>
                                                                        <button type="button" class="btn btn-outline-secondary" data-bs-toggle="collapse" data-bs-target="#campaign-{{ $campaign->id }}-events" aria-expanded="false" aria-controls="campaign-{{ $campaign->id }}-events">
                                                                            <i class="bi bi-clock-history"></i>
                                                                        </button>
                                                                    </div>
                                                                @endcan
                                                            </td>
                                                        </tr>
                                                        <tr class="collapse" id="campaign-{{ $campaign->id }}-events">
                                                            <td colspan="6" class="bg-light">
                                                                <div class="p-3">
                                                                    <h6 class="mb-3 text-uppercase text-muted">{{ __('Recent executions') }}</h6>
                                                                    <ul class="list-unstyled mb-0">
                                                                        @forelse($campaign->events as $event)
                                                                            <li class="d-flex justify-content-between border-bottom py-2">
                                                                                <span>
                                                                                    <strong>{{ $event->event_type }}</strong>
                                                                                    <span class="badge bg-secondary ms-2">{{ __($event->status) }}</span>
                                                                                </span>
                                                                                <span class="text-muted small">
                                                                                    {{ optional($event->dispatched_at ?? $event->scheduled_at)->format('Y-m-d H:i') ?? '—' }}
                                                                                </span>
                                                                            </li>
                                                                        @empty
                                                                            <li class="text-muted">{{ __('No executions yet.') }}</li>
                                                                        @endforelse
                                                                    </ul>
                                                                </div>
                                                            </td>
                                                        </tr>
                                                    @empty
                                                        <tr data-empty-state="campaigns" class="campaigns-empty-state">
                                                            <td colspan="6" class="text-center text-muted py-5">
                                                                <i class="bi bi-ui-radios-grid fs-3 d-block mb-2"></i>
                                                                {{ __('No campaigns configured yet. Start by creating one on the left.') }}
                                                            </td>
                                                        </tr>
                                                    @endforelse
                                                    </tbody>
                                                </table>
                                            </div>





                                            
                                        </div>
                                    </div>



                                </div>
                            </div>
                        </div>



                        <div class="tab-pane fade" id="tab-automation" role="tabpanel" aria-labelledby="automation-tab">
                            <div class="row g-4">
                                <div class="col-lg-4">
                                    <div class="card border shadow-sm h-100">
                                        <div class="card-header bg-light">
                                            <h5 class="mb-0">{{ __('Event Catalogue') }}</h5>
                                            <small class="text-muted">{{ __('Key signals that can automatically launch campaigns.') }}</small>
                                        </div>
                                        <div class="card-body">
                                            <ul class="list-group list-group-flush">
                                                @foreach($automationEvents as $event)
                                                    <li class="list-group-item d-flex justify-content-between align-items-start">
                                                        <div class="ms-2 me-auto">
                                                            <div class="fw-bold">{{ $event['label'] }}</div>
                                                            <code class="text-primary">{{ $event['key'] }}</code>
                                                        </div>
                                                        <span class="badge bg-secondary rounded-pill">{{ __('Automation') }}</span>
                                                    </li>




                                                @endforeach



                                                                                            </ul>
                                            <p class="text-muted small mt-3 mb-0">
                                                {{ __('Use these keys when defining event-driven campaigns. Additional events can be dispatched from services, jobs, or observers.') }}
                                            </p>

                                            

                                            </div>
                                    </div>






                                </div>

                                
                                <div class="col-lg-8">
                                    <div class="card border shadow-sm h-100">
                                        <div class="card-header bg-light">
                                            <h5 class="mb-0">{{ __('Trigger automation manually') }}</h5>
                                            <small class="text-muted">{{ __('Useful for testing event-driven journeys or forcing replays for selected cohorts.') }}</small>
                                        </div>
                                        <div class="card-body">
                                            <form
                                                id="automation-trigger-form"
                                                action="{{ route('notification.automation.trigger') }}"
                                                method="post"
                                                class="create-form row g-3"
                                                data-success-function="handleAutomationTriggered"
                                                data-parsley-validate
                                            >

                                                
                                            @csrf
                                                <div class="col-md-6">
                                                    <label class="form-label" for="automation-event-key">{{ __('Event Key') }}</label>
                                                    <select class="form-select" id="automation-event-key" name="event_key" required>
                                                        <option value="" selected disabled>{{ __('Choose event to trigger') }}</option>
                                                        @foreach($automationEvents as $event)
                                                            <option value="{{ $event['key'] }}">{{ $event['label'] }}</option>
                                                        @endforeach
                                                    </select>
                                                </div>
                                                <div class="col-md-6">
                                                    <label class="form-label" for="automation-user-id">{{ __('Target User ID (optional)') }}</label>
                                                    <input type="number" class="form-control" id="automation-user-id" name="payload[user_id]" placeholder="1234">
                                                </div>
                                                <div class="col-12">
                                                    <label class="form-label" for="automation-payload">{{ __('Additional Payload (JSON)') }}</label>
                                                    <textarea id="automation-payload" name="payload[meta]" class="form-control" rows="3" placeholder='{ "offer": "summer-bundle" }'></textarea>
                                                    <small class="text-muted">{{ __('Payload is merged with campaign metadata and delivered to jobs & notifications.') }}</small>
                                                </div>
                                                <div class="col-12 d-flex justify-content-end">
                                                    <button type="submit" class="btn btn-warning">
                                                        <i class="bi bi-lightning-fill"></i> {{ __('Fire Event') }}
                                                    </button>
                                                </div>
                                            </form>
                                        </div>



                                    </div>
                                </div>
                            </div>
                        </div>




                        <div class="tab-pane fade" id="tab-reports" role="tabpanel" aria-labelledby="reports-tab">
                            <div class="row g-4">
                                <div class="col-12">
                                    <div class="row g-3">
                                        <div class="col-sm-6 col-xl-3">
                                            <div class="card border shadow-sm h-100">
                                                <div class="card-body">
                                                    <h6 class="text-muted text-uppercase">{{ __('Total Campaigns') }}</h6>
                                                    <h3 class="fw-bold" data-metric="total-campaigns">{{ $dashboardMetrics['total_campaigns'] ?? 0 }}</h3>
                                                
                                                </div>
                                            </div>
                                        </div>
                                        <div class="col-sm-6 col-xl-3">
                                            <div class="card border shadow-sm h-100">
                                                <div class="card-body">
                                                    <h6 class="text-muted text-uppercase">{{ __('Active / Scheduled') }}</h6>
                                                    <h3 class="fw-bold" data-metric="event-driven-campaigns">{{ $dashboardMetrics['event_driven_campaigns'] ?? 0 }}</h3>
                                                
                                                </div>
                                            </div>
                                        </div>
                                        <div class="col-sm-6 col-xl-3">
                                            <div class="card border shadow-sm h-100">
                                                <div class="card-body">
                                                    <h6 class="text-muted text-uppercase">{{ __('Event Driven Journeys') }}</h6>
                                                    <h3 class="fw-bold">{{ $dashboardMetrics['event_driven_campaigns'] ?? 0 }}</h3>
                                                </div>
                                            </div>
                                        </div>
                                        <div class="col-sm-6 col-xl-3">
                                            <div class="card border shadow-sm h-100">
                                                <div class="card-body">
                                                    <h6 class="text-muted text-uppercase">{{ __('Delivery Rate') }}</h6>
                                                    <h3 class="fw-bold">{{ $dashboardMetrics['delivery_rate'] ?? 0 }}%</h3>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                                <div class="col-xl-6">
                                    <div class="card border shadow-sm h-100">
                                        <div class="card-header bg-light">
                                            <h5 class="mb-0">{{ __('Engagement Funnel') }}</h5>
                                        </div>
                                        <div class="card-body">
                                            <div class="d-flex flex-column gap-3">
                                                <div>
                                                    <span class="fw-semibold">{{ __('Open Rate') }}</span>
                                                    <div class="progress" style="height: 8px;">
                                                        <div class="progress-bar bg-success" role="progressbar" style="width: {{ $dashboardMetrics['open_rate'] ?? 0 }}%" aria-valuenow="{{ $dashboardMetrics['open_rate'] ?? 0 }}" aria-valuemin="0" aria-valuemax="100"></div>
                                                    </div>
                                                    <small class="text-muted">{{ $dashboardMetrics['open_rate'] ?? 0 }}%</small>
                                                </div>
                                                <div>
                                                    <span class="fw-semibold">{{ __('Click Rate') }}</span>
                                                    <div class="progress" style="height: 8px;">
                                                        <div class="progress-bar bg-info" role="progressbar" style="width: {{ $dashboardMetrics['click_rate'] ?? 0 }}%" aria-valuenow="{{ $dashboardMetrics['click_rate'] ?? 0 }}" aria-valuemin="0" aria-valuemax="100"></div>
                                                    </div>
                                                    <small class="text-muted">{{ $dashboardMetrics['click_rate'] ?? 0 }}%</small>
                                                </div>
                                                <div>
                                                    <span class="fw-semibold">{{ __('Reactivation Rate') }}</span>
                                                    <div class="progress" style="height: 8px;">
                                                        <div class="progress-bar bg-warning" role="progressbar" style="width: {{ $dashboardMetrics['reactivation_rate'] ?? 0 }}%" aria-valuenow="{{ $dashboardMetrics['reactivation_rate'] ?? 0 }}" aria-valuemin="0" aria-valuemax="100"></div>
                                                    </div>
                                                    <small class="text-muted">{{ $dashboardMetrics['reactivation_rate'] ?? 0 }}%</small>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                                <div class="col-xl-6">
                                    <div class="card border shadow-sm h-100">
                                        <div class="card-header bg-light">
                                            <h5 class="mb-0">{{ __('Recent Deliveries') }}</h5>
                                            <small class="text-muted">{{ __('Track last notifications and engagement outcomes.') }}</small>
                                        </div>
                                        <div class="card-body">
                                            <div class="table-responsive">
                                                <table class="table table-striped align-middle">
                                                    <thead>
                                                    <tr>
                                                        <th>{{ __('Campaign') }}</th>
                                                        <th>{{ __('User') }}</th>
                                                        <th>{{ __('Status') }}</th>
                                                        <th>{{ __('Delivered At') }}</th>
                                                    </tr>
                                                    </thead>
                                                    <tbody>
                                                    @forelse($recentDeliveries as $delivery)
                                                        <tr>
                                                            <td>{{ optional($delivery->campaign)->name ?? __('Broadcast') }}</td>
                                                            <td>{{ optional($delivery->user)->name ?? ('#' . $delivery->user_id) }}</td>
                                                            <td><span class="badge bg-secondary text-uppercase">{{ __($delivery->status) }}</span></td>
                                                            <td>{{ optional($delivery->delivered_at)->format('Y-m-d H:i') ?? '—' }}</td>
                                                        </tr>
                                                    @empty
                                                        <tr>
                                                            <td colspan="4" class="text-center text-muted py-4">{{ __('No deliveries logged yet.') }}</td>
                                                        </tr>
                                                    @endforelse
                                                    </tbody>
                                                </table>
                                            </div>
                                        </div>
                                    </div>
                                </div>





                            </div>

                        </div>
                    </div>
                </div>
            </div>
        </section>
    </div>
@endsection









@push('scripts')
    <script>
        document.addEventListener('DOMContentLoaded', function () {
            const includeImage = document.getElementById('include_image');
            const imageWrapper = document.getElementById('show_image');
            if (includeImage) {
                includeImage.addEventListener('change', function () {
                    imageWrapper.style.display = this.checked ? 'block' : 'none';
                });
            }

            const triggerType = document.getElementById('trigger-type');
            const scheduledFields = document.querySelectorAll('.scheduled-only');
            const eventFields = document.querySelectorAll('.event-only');

            function toggleTriggerSections() {
                const value = triggerType.value;
                scheduledFields.forEach(field => field.classList.toggle('d-none', value !== 'scheduled'));
                eventFields.forEach(field => field.classList.toggle('d-none', value !== 'event'));
            }

            if (triggerType) {
                triggerType.addEventListener('change', toggleTriggerSections);
                toggleTriggerSections();
            }

            const segmentsWrapper = document.getElementById('campaign-segments');
            const addSegmentButton = document.getElementById('add-segment');
            let segmentIndex = 0;

            function segmentTemplate(index) {
                return `
                    <div class="segment-card border rounded p-3 mb-3" data-index="${index}">
                        <div class="d-flex justify-content-between align-items-center mb-2">
                            <h6 class="mb-0">${'{{ __('Segment') }}'} #${index + 1}</h6>
                            <button type="button" class="btn btn-sm btn-link text-danger remove-segment" data-index="${index}">
                                <i class="bi bi-x-circle"></i>
                            </button>
                        </div>
                        <div class="row g-3">
                            <div class="col-md-6">
                                <label class="form-label">{{ __('Segment Name') }}</label>
                                <input type="text" class="form-control" name="segments[${index}][name]" placeholder="{{ __('High value buyers') }}" required>
                            </div>
                            <div class="col-md-6">
                                <label class="form-label">{{ __('Description') }}</label>
                                <input type="text" class="form-control" name="segments[${index}][description]" placeholder="{{ __('Users with >3 orders last month') }}">
                            </div>
                            <div class="col-md-12">
                                <label class="form-label">{{ __('Account Types') }}</label>
                                <select class="form-select" name="segments[${index}][filters][account_types][]" multiple>
                                    <option value="individual">{{ __('Individual') }}</option>
                                    <option value="business">{{ __('Business') }}</option>
                                    <option value="real_estate">{{ __('Real Estate') }}</option>
                                </select>
                                <small class="text-muted">{{ __('Hold CTRL or CMD to select multiple types.') }}</small>
                            </div>
                            <div class="col-md-6">
                                <label class="form-label">{{ __('Minimum orders') }}</label>
                                <input type="number" min="0" class="form-control" name="segments[${index}][filters][minimum_orders]" placeholder="3">
                            </div>
                            <div class="col-md-6">
                                <label class="form-label">{{ __('Minimum spend (total)') }}</label>
                                <input type="number" min="0" class="form-control" name="segments[${index}][filters][minimum_spent]" step="0.01" placeholder="150">
                            </div>
                            <div class="col-md-6">
                                <label class="form-label">{{ __('Inactive for (days)') }}</label>
                                <input type="number" min="0" class="form-control" name="segments[${index}][filters][inactive_days]" placeholder="30">
                            </div>
                            <div class="col-md-6">
                                <label class="form-label">{{ __('Minimum referrals') }}</label>
                                <input type="number" min="0" class="form-control" name="segments[${index}][filters][minimum_referrals]" placeholder="2">
                            </div>
                            <div class="col-md-6">
                                <label class="form-label">{{ __('Minimum referral points') }}</label>
                                <input type="number" min="0" class="form-control" name="segments[${index}][filters][minimum_points]" placeholder="50">
                            </div>
                            <div class="col-md-6">
                                <label class="form-label">{{ __('Last order status') }}</label>
                                <select class="form-select" name="segments[${index}][filters][last_order_status]">
                                    <option value="">{{ __('Any') }}</option>
                                    @foreach(\App\Models\Order::getStatusList() as $statusCode => $statusLabel)
                                        <option value="{{ $statusCode }}">{{ $statusLabel }}</option>
                                    @endforeach
                                </select>
                            </div>
                            <div class="col-12">
                                <label class="form-label">{{ __('Purchased items (IDs)') }}</label>
                                <select class="form-select" name="segments[${index}][filters][purchased_item_ids][]" multiple>
                                    @foreach($item_list as $row)
                                        <option value="{{ $row->id }}">#{{ $row->id }} – {{ $row->name }}</option>
                                    @endforeach
                                </select>
                                <small class="text-muted">{{ __('Target users who purchased specific products or services.') }}</small>
                            </div>
                        </div>
                    </div>
                `;
            }

            function addSegment() {

                if (!segmentsWrapper) {
                    return;

                }
                const wrapper = document.createElement('div');
                wrapper.innerHTML = segmentTemplate(segmentIndex);
                segmentsWrapper.appendChild(wrapper.firstElementChild);
                segmentIndex++;
            }

            if (addSegmentButton) {
                addSegmentButton.addEventListener('click', addSegment);
                addSegment();
            }









             if (segmentsWrapper) {
                segmentsWrapper.addEventListener('click', function (event) {
                    if (event.target.closest('.remove-segment')) {
                        const card = event.target.closest('.segment-card');
                        if (card) {
                            card.remove();
                        }
                    }
                });
            }

            const campaignsList = document.getElementById('campaigns-list');
            const campaignsTable = document.getElementById('campaigns-table');
            const campaignsTabTrigger = document.getElementById('campaigns-tab');
            const automationForm = document.getElementById('automation-trigger-form');
            const dispatchUrlTemplate = campaignsList ? campaignsList.dataset.dispatchUrlTemplate : '';
            const csrfMeta = document.querySelector('meta[name="csrf-token"]');
            const csrfToken = csrfMeta ? csrfMeta.getAttribute('content') : '';
            const canDispatch = campaignsTable ? campaignsTable.dataset.canDispatch === '1' : false;
            const translate = typeof window.trans === 'function' ? window.trans : function (label) { return label; };
            const locale = {
                segment: @json(__('Segment')),
                defaultSegment: @json(__('All users (no segment)')),
                recentExecutions: @json(__('Recent executions')),
                noExecutions: @json(__('No executions yet.')),
                runNow: @json(__('Run Now')),
            };

            function limitText(text, maxLength = 60) {
                if (typeof text !== 'string') {
                    return '';
                }
                const trimmed = text.trim();
                if (trimmed.length <= maxLength) {
                    return trimmed;
                }
                return trimmed.slice(0, maxLength - 1) + '…';
            }

            function formatDateTime(value) {
                if (!value) {
                    return '—';
                }
                const date = new Date(value);
                if (Number.isNaN(date.getTime())) {
                    return value;
                }
                const pad = function (number) {
                    return String(number).padStart(2, '0');
                };
                return date.getFullYear() + '-' + pad(date.getMonth() + 1) + '-' + pad(date.getDate()) + ' ' + pad(date.getHours()) + ':' + pad(date.getMinutes());
            }

            function updateMetric(metricName, delta) {
                if (!delta) {
                    return;
                }
                const metricElement = document.querySelector('[data-metric="' + metricName + '"]');
                if (!metricElement) {
                    return;
                }
                const currentValue = parseInt(metricElement.textContent, 10);
                if (Number.isNaN(currentValue)) {
                    return;
                }
                metricElement.textContent = currentValue + delta;
            }

            function resetSegments() {
                if (!segmentsWrapper) {
                    return;
                }
                segmentsWrapper.innerHTML = '';
                segmentIndex = 0;
                addSegment();
            }

            function insertCampaignRow(campaign) {
                if (!campaignsList || !campaign || !campaign.id) {
                    return;
                }

                const emptyRow = campaignsList.querySelector('[data-empty-state="campaigns"]');
                if (emptyRow) {
                    emptyRow.remove();
                }

                const fragment = document.createDocumentFragment();
                const collapseId = 'campaign-' + campaign.id + '-events';

                const mainRow = document.createElement('tr');
                mainRow.dataset.campaignId = campaign.id;

                const nameCell = document.createElement('td');
                const nameStrong = document.createElement('strong');
                nameStrong.textContent = campaign.name || '';
                nameCell.appendChild(nameStrong);

                if (campaign.notification_body) {
                    const bodyDiv = document.createElement('div');
                    bodyDiv.className = 'small text-muted';
                    bodyDiv.textContent = limitText(campaign.notification_body);
                    nameCell.appendChild(bodyDiv);
                }

                mainRow.appendChild(nameCell);

                const triggerCell = document.createElement('td');
                const triggerBadge = document.createElement('span');
                triggerBadge.className = 'badge bg-secondary text-uppercase';
                triggerBadge.textContent = translate(campaign.trigger_type || '');
                triggerCell.appendChild(triggerBadge);
                mainRow.appendChild(triggerCell);

                const statusCell = document.createElement('td');
                const statusBadge = document.createElement('span');
                const status = campaign.status || 'draft';
                let statusClass = 'bg-secondary';
                if (status === 'active') {
                    statusClass = 'bg-success';
                } else if (status === 'scheduled') {
                    statusClass = 'bg-info';
                }
                statusBadge.className = 'badge ' + statusClass + ' text-uppercase';
                statusBadge.textContent = translate(status);
                statusCell.appendChild(statusBadge);
                mainRow.appendChild(statusCell);

                const segmentsCell = document.createElement('td');
                const segmentsContainer = document.createElement('div');
                segmentsContainer.className = 'd-flex flex-column gap-1';
                const segments = Array.isArray(campaign.segments) ? campaign.segments : [];
                if (segments.length > 0) {
                    segments.forEach(function (segment) {
                        const badge = document.createElement('span');
                        badge.className = 'badge bg-light text-dark border';
                        const size = segment && segment.estimated_size != null ? segment.estimated_size : 0;
                        const labelText = segment && segment.name ? segment.name + ' (' + size + ')' : locale.segment + ' (' + size + ')';
                        badge.textContent = labelText;
                        segmentsContainer.appendChild(badge);
                    });
                } else {
                    const badge = document.createElement('span');
                    badge.className = 'badge bg-light text-muted';
                    badge.textContent = locale.defaultSegment;
                    segmentsContainer.appendChild(badge);
                }
                segmentsCell.appendChild(segmentsContainer);
                mainRow.appendChild(segmentsCell);

                const nextRunCell = document.createElement('td');
                if (campaign.scheduled_at) {
                    nextRunCell.textContent = formatDateTime(campaign.scheduled_at);
                } else {
                    const muted = document.createElement('span');
                    muted.className = 'text-muted';
                    muted.textContent = '—';
                    nextRunCell.appendChild(muted);
                }
                mainRow.appendChild(nextRunCell);

                const actionsCell = document.createElement('td');
                actionsCell.className = 'text-end';
                if (canDispatch && dispatchUrlTemplate && csrfToken) {
                    const btnGroup = document.createElement('div');
                    btnGroup.className = 'btn-group btn-group-sm';

                    const form = document.createElement('form');
                    form.className = 'd-inline';
                    form.method = 'post';
                    form.action = dispatchUrlTemplate.replace('__CAMPAIGN_ID__', campaign.id);

                    const csrfInput = document.createElement('input');
                    csrfInput.type = 'hidden';
                    csrfInput.name = '_token';
                    csrfInput.value = csrfToken;
                    form.appendChild(csrfInput);

                    const submitButton = document.createElement('button');
                    submitButton.type = 'submit';
                    submitButton.className = 'btn btn-outline-primary';
                    submitButton.title = locale.runNow;
                    submitButton.innerHTML = '<i class="bi bi-play"></i>';
                    form.appendChild(submitButton);

                    btnGroup.appendChild(form);

                    const collapseButton = document.createElement('button');
                    collapseButton.type = 'button';
                    collapseButton.className = 'btn btn-outline-secondary';
                    collapseButton.setAttribute('data-bs-toggle', 'collapse');
                    collapseButton.setAttribute('data-bs-target', '#' + collapseId);
                    collapseButton.setAttribute('aria-expanded', 'false');
                    collapseButton.setAttribute('aria-controls', collapseId);
                    collapseButton.innerHTML = '<i class="bi bi-clock-history"></i>';
                    btnGroup.appendChild(collapseButton);

                    actionsCell.appendChild(btnGroup);
                }
                mainRow.appendChild(actionsCell);

                fragment.appendChild(mainRow);

                const eventsRow = document.createElement('tr');
                eventsRow.className = 'collapse';
                eventsRow.id = collapseId;
                const eventsCell = document.createElement('td');
                eventsCell.colSpan = 6;
                eventsCell.className = 'bg-light';

                const eventsWrapper = document.createElement('div');
                eventsWrapper.className = 'p-3';
                const eventsTitle = document.createElement('h6');
                eventsTitle.className = 'mb-3 text-uppercase text-muted';
                eventsTitle.textContent = locale.recentExecutions;
                eventsWrapper.appendChild(eventsTitle);

                const eventsList = document.createElement('ul');
                eventsList.className = 'list-unstyled mb-0';
                const events = Array.isArray(campaign.events) ? campaign.events : [];
                if (events.length > 0) {
                    events.forEach(function (event) {
                        const item = document.createElement('li');
                        item.className = 'd-flex justify-content-between border-bottom py-2';

                        const left = document.createElement('span');
                        const strong = document.createElement('strong');
                        strong.textContent = event && event.event_type ? event.event_type : '';
                        left.appendChild(strong);

                        const badge = document.createElement('span');
                        badge.className = 'badge bg-secondary ms-2';
                        badge.textContent = translate(event && event.status ? event.status : '');
                        left.appendChild(badge);

                        const right = document.createElement('span');
                        right.className = 'text-muted small';
                        const timestamp = event && event.dispatched_at ? event.dispatched_at : (event && event.scheduled_at ? event.scheduled_at : '');
                        right.textContent = timestamp ? formatDateTime(timestamp) : '—';

                        item.appendChild(left);
                        item.appendChild(right);
                        eventsList.appendChild(item);
                    });
                } else {
                    const emptyItem = document.createElement('li');
                    emptyItem.className = 'text-muted';
                    emptyItem.textContent = locale.noExecutions;
                    eventsList.appendChild(emptyItem);
                }

                eventsWrapper.appendChild(eventsList);
                eventsCell.appendChild(eventsWrapper);
                eventsRow.appendChild(eventsCell);
                fragment.appendChild(eventsRow);

                campaignsList.prepend(fragment);

                mainRow.classList.add('table-success');
                setTimeout(function () {
                    mainRow.classList.remove('table-success');
                }, 4000);
            }

            const handleCampaignCreated = function (response) {
                const campaign = response && response.data ? response.data : null;
                if (!campaign) {
                    window.location.reload();
                    return;
                }

                if (campaignsTabTrigger) {
                    if (window.bootstrap && typeof window.bootstrap.Tab === 'function') {
                        new window.bootstrap.Tab(campaignsTabTrigger).show();
                    } else {
                        campaignsTabTrigger.click();
















                    }
                }

                resetSegments();



                
                if (triggerType) {
                    toggleTriggerSections();
                }

                if (campaignsList) {
                    insertCampaignRow(campaign);
                } else {
                    window.location.reload();
                }

                updateMetric('total-campaigns', 1);

                if (['active', 'scheduled'].includes(campaign.status)) {
                    updateMetric('active-campaigns', 1);
                }

                if (campaign.trigger_type === 'event') {
                    updateMetric('event-driven-campaigns', 1);
                }
            };



                     const handleAutomationTriggered = function () {
                if (!automationForm) {
                    return;
                }
                automationForm.classList.add('border', 'border-success', 'rounded');
                setTimeout(function () {
                    automationForm.classList.remove('border', 'border-success', 'rounded');
                }, 2000);
            };

            window.handleCampaignCreated = handleCampaignCreated;
            window.handleAutomationTriggered = handleAutomationTriggered;

        });
    </script>
@endpush
