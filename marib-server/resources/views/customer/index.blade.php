@extends('layouts.main')

@section('title')
    {{ __('Users') }}
@endsection

@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first"></div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        <div class="card">
            <div class="card-body">
                <div class="row">
                    <div class="col-12">
                        <table class="table-borderless table-striped" aria-describedby="mydesc" id="table_list"
                               data-toggle="table" data-url="{{ route('customer.list') }}" data-click-to-select="true"
                               data-side-pagination="server" data-pagination="true"
                               data-page-list="[5, 10, 20, 50, 100, 200]" data-search="true" data-toolbar="#toolbar"
                               data-show-columns="true" data-show-refresh="true" data-fixed-columns="true"
                               data-fixed-number="1" data-fixed-right-number="1" data-trim-on-search="false"
                               data-responsive="true" data-sort-name="id" data-sort-order="desc"
                               data-escape="true"
                               data-pagination-successively-size="3" data-query-params="queryParams" data-table="users" data-status-column="deleted_at"
                               data-show-export="true" data-export-options='{"fileName": "customer-list","ignoreColumn": ["operate"]}' data-export-types="['pdf','json', 'xml', 'csv', 'txt', 'sql', 'doc', 'excel']"
                               data-mobile-responsive="true">
                            <thead class="thead-dark">
                            <tr>
                                <th scope="col" data-field="id" data-sortable="true">{{ __('ID') }}</th>
                                <th scope="col" data-field="profile" data-formatter="imageFormatter">{{ __('Profile') }}</th>
                                <th scope="col" data-field="name" data-sortable="true">{{ __('Name') }}</th>
                                <th scope="col" data-field="email" data-sortable="true">{{ __('Email') }}</th>
                                <th scope="col" data-field="mobile" data-sortable="true">{{ __('Mobile') }}</th>
                                <th scope="col" data-field="account_type" data-formatter="accountTypeFormatter" data-sortable="true" data-filter-control="select">{{ __('User Type') }}</th>
                                <th scope="col" data-field="type" data-sortable="true">{{ __('Type') }}</th>
                                <th scope="col" data-field="email_verified_at" data-formatter="verificationStatusFormatter" data-sortable="true" data-filter-control="select">{{ __('حالة التوثيق') }}</th>
                                <th scope="col" data-field="terms_and_policy_accepted" data-formatter="termsAcceptanceFormatter" data-sortable="true">{{ __('قبول الشروط') }}</th>

                                <th scope="col" data-field="items_count" data-sortable="true">{{ __('Total Post') }}</th>
                                <th scope="col" data-field="status" data-formatter="statusSwitchFormatter" data-sortable="false">{{ __('Status') }}</th>
                                <th scope="col" data-field="operate" data-escape="false" data-align="center" data-sortable="false" data-events="userEvents">{{ __('Action') }}</th>
                            </tr>
                            </thead>
                        </table>
                    </div>
                </div>
            </div>
        </div>
        <div id="assignPackageModal" class="modal fade" tabindex="-1" role="dialog" aria-labelledby="myModalLabel1"
             aria-hidden="true">
            <div class="modal-dialog">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title" id="myModalLabel1">{{ __('Assign Packages') }}</h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                    </div>
                    <div class="modal-body">
                        <form class="create-form" action="{{ route('customer.assign.package') }}" method="POST" data-parsley-validate data-success-function="assignApprovalSuccess">
                            @csrf
                            <input type="hidden" name="user_id" id='user_id'>
                            <div class="form-group row">
                                <div class="col-md-6">
                                    <input type="radio" id="item_package" class="package_type form-check-input" name="package_type" value="item_listing" required>
                                    <label for="item_package">{{ __('Item Listing Package') }}</label>
                                </div>
                                <div class="col-md-6">
                                    <input type="radio" id="advertisement_package" class="package_type form-check-input" name="package_type" value="advertisement" required>
                                    <label for="advertisement_package">{{ __('Advertisement Package') }}</label>
                                </div>
                            </div>
                            <div class="row mt-3" id="item-listing-package-div" style="display: none;">
                                <div class="form-group col-md-12">
                                    <label for="package">{{__("Select Package")}}</label>
                                    <select name="package_id" class="form-select package" id="item-listing-package" aria-label="Package">
                                        <option value="" disabled selected>Select Option</option>
                                        @foreach($itemListingPackage as $package)
                                            <option value="{{$package->id}}" data-details="{{json_encode($package)}}">{{$package->name}}</option>
                                        @endforeach
                                    </select>
                                </div>
                            </div>

                            <div class="row mt-3" id="advertisement-package-div" style="display: none;">
                                <div class="form-group col-md-12">
                                    <label for="package">{{__("Select Package")}}</label>
                                    <select name="package_id" class="form-select package" id="advertisement-package" aria-label="Package">
                                        <option value="" disabled selected>Select Option</option>
                                        @foreach($advertisementPackage as $package)
                                            <option value="{{$package->id}}" data-details="{{json_encode($package)}}">{{$package->name}}</option>
                                        @endforeach
                                    </select>
                                </div>
                            </div>

                            <div id="package_details" class="mt-3" style="display: none;">
                                <p><strong>Name:</strong> <span id="package_name"></span></p>
                                <p><strong>Price:</strong> <span id="package_price"></span></p>
                                <p><strong>Final Price:</strong> <span id="package_final_price"></span></p>
                                <p><strong>Limitation:</strong> <span id="package_duration"></span></p>
                            </div>
                            <div class="form-group row payment" style="display: none">
                                <div class="col-md-6">
                                    <input type="radio" id="cash_payment" class="payment_gateway form-check-input" name="payment_gateway" value="cash" required>
                                    <label for="cash_payment">{{ __('Cash') }}</label>
                                </div>
                                <div class="col-md-6">
                                    <input type="radio" id="cheque_payment" class="payment_gateway form-check-input" name="payment_gateway" value="cheque" required>
                                    <label for="cheque_payment">{{ __('Cheque') }}</label>
                                </div>
                            </div>
                            <div class="form-group cheque mt-3" style="display: none">
                                <label for="cheque">{{ __('Add cheque number') }}</label>
                                <input type="text" id="cheque" class="form-control" name="cheque_number" data-parsley-required="true">
                            </div>
                            <input type="submit" value="{{__("Save")}}" class="btn btn-primary mt-3">
                        </form>
                    </div>
                </div>
            </div>
        </div>
    </section>

    <!-- Modal para editar información adicional -->
    <div class="modal fade" id="additionalInfoModal" tabindex="-1" aria-labelledby="additionalInfoModalLabel" aria-hidden="true">
        <div class="modal-dialog modal-lg">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title" id="additionalInfoModalLabel">{{ __('معلومات إضافية للعميل') }}</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body">
                    <div class="alert alert-info mb-4">
                        <i class="fa fa-info-circle me-2"></i>
                        {{ __('يمكنك إضافة معلومات اتصال إضافية ومعلومات دفع بنكية وموقع للعميل. جميع الحقول اختيارية.') }}
                    </div>
                    
                    <form id="additionalInfoForm" method="POST" action="{{ route('customer.update.additional.info') }}" class="create-form">
                        @csrf
                        <input type="hidden" name="user_id" id="info_user_id">
                        
                        <div class="mb-3">
                            <h5><i class="fa fa-phone-square text-primary me-2"></i>{{ __('معلومات الاتصال الإضافية') }}</h5>
                            <div id="contactsContainer">
                                <div class="row contact-entry mb-2">
                                    <div class="col-md-5">
                                        <input type="text" class="form-control" name="contact_labels[]" placeholder="{{ __('نوع الاتصال (واتساب، تيليجرام، إلخ)') }}">
                                    </div>
                                    <div class="col-md-5">
                                        <input type="text" class="form-control" name="contact_values[]" placeholder="{{ __('رقم أو معرف الاتصال') }}">
                                    </div>
                                    <div class="col-md-2">
                                        <button type="button" class="btn btn-danger remove-entry"><i class="bi bi-dash-circle"></i></button>
                                    </div>
                                </div>
                            </div>
                            <button type="button" class="btn btn-sm btn-primary" id="addContact">
                                <i class="fa fa-plus-circle"></i> {{ __('إضافة وسيلة اتصال') }}
                            </button>
                        </div>
                        
                        <div class="mb-3">
                            <h5><i class="fa fa-credit-card text-primary me-2"></i>{{ __('معلومات الدفع البنكية') }}</h5>
                            <div id="paymentsContainer">
                                <div class="row payment-entry mb-2">
                                    <div class="col-md-5">
                                        <input type="text" class="form-control" name="payment_labels[]" placeholder="{{ __('اسم البنك / طريقة الدفع') }}">
                                    </div>
                                    <div class="col-md-5">
                                        <input type="text" class="form-control" name="payment_values[]" placeholder="{{ __('رقم الحساب / معلومات الدفع') }}">
                                    </div>
                                    <div class="col-md-2">
                                        <button type="button" class="btn btn-danger remove-entry"><i class="bi bi-dash-circle"></i></button>
                                    </div>
                                </div>
                            </div>
                            <button type="button" class="btn btn-sm btn-primary" id="addPayment">
                                <i class="fa fa-plus-circle"></i> {{ __('إضافة طريقة دفع') }}
                            </button>
                        </div>
                        
                        <div class="mb-3">
                            <h5><i class="fa fa-map-marker text-primary me-2"></i>{{ __('المكان') }}</h5>
                            <input type="text" class="form-control" name="location" id="location" placeholder="{{ __('أدخل الموقع') }}">
                        </div>
                        
                        <div class="d-grid">
                            <button type="submit" class="btn btn-primary">{{ __('حفظ المعلومات') }}</button>
                        </div>
                    </form>
                </div>
            </div>
        </div>
    </div>
@endsection
@section('js')
    <script>
        function assignApprovalSuccess() {
            $('#assignPackageModal').modal('hide');
        }

        function termsAcceptanceFormatter(value, row) {
            if (value === true || value === 1 || value === '1' || value === 'true') {
                return '<span class="badge bg-success"><i class="bi bi-check-lg"></i> نعم</span>';
            } else {
                return '<span class="badge bg-danger"><i class="bi bi-x-lg"></i> لا </span>';
            }
        }

        // Formatter para los contactos adicionales
        function additionalContactsFormatter(value, row) {
            if (!value) return '-';
            
            try {
                let contacts = typeof value === 'object' ? value : JSON.parse(value);
                let html = '<ul class="list-unstyled mb-0">';
                
                for (let key in contacts) {
                    html += `<li><strong>${key}:</strong> ${contacts[key]}</li>`;
                }
                
                html += '</ul>';
                return html;
            } catch (e) {
                return '-';
            }
        }

        // Formatter para la información de pago
        function paymentInfoFormatter(value, row) {
            if (!value) return '-';
            
            try {
                let payments = typeof value === 'object' ? value : JSON.parse(value);
                let html = '<ul class="list-unstyled mb-0">';
                
                for (let key in payments) {
                    html += `<li><strong>${key}:</strong> ${payments[key]}</li>`;
                }
                
                html += '</ul>';
                return html;
            } catch (e) {
                return '-';
            }
        }

        // Formatter for verification status
        function verificationStatusFormatter(value, row) {
            if (value) {
                return '<span class="badge bg-success">موثق</span>';
            } else {
                return '<span class="badge bg-danger">غير موثق</span>';
            }
        }
        
        // Add filter controls to queryParams
        function queryParams(params) {
            const userType = $('#user_type_filter').val();
            const verified = $('#verified_filter').val();

            if (userType !== '') {
                params.account_type = userType;
            }

            if (verified !== '') {
                params.email_verified_at = verified;
            }

            return params;
        }

        // Eventos para el manejo de los campos dinámicos
        $(document).ready(function() {
            var filterHtml = '<div class="row mb-3">' +
                '<div class="col-md-3">' +
                '<select id="user_type_filter" class="form-select">' +
                '<option value="">نوع المستخدم</option>' +
                '<option value="1">فردي</option>' +
                '<option value="2">عقاري</option>' +
                '<option value="3">تجاري</option>' +
                '</select>' +
                '</div>' +
                '<div class="col-md-3">' +
                '<select id="verified_filter" class="form-select">' +
                '<option value="">حالة التوثيق</option>' +
                '<option value="1">موثق</option>' +
                '<option value="0">غير موثق</option>' +
                '</select>' +
                '</div>' +
                '</div>';
            $('#table_list').before(filterHtml);
            $('#user_type_filter, #verified_filter').change(function() {
                $('#table_list').bootstrapTable('refresh');
            });
            
            // Agregar contacto
            $('#addContact').click(function() {
                let newRow = `
                    <div class="row contact-entry mb-2">
                        <div class="col-md-5">
                            <input type="text" class="form-control" name="contact_labels[]" placeholder="{{ __('نوع الاتصال (واتساب، تيليجرام، إلخ)') }}">
                        </div>
                        <div class="col-md-5">
                            <input type="text" class="form-control" name="contact_values[]" placeholder="{{ __('رقم أو معرف الاتصال') }}">
                        </div>
                        <div class="col-md-2">
                            <button type="button" class="btn btn-danger remove-entry"><i class="bi bi-dash-circle"></i></button>
                        </div>
                    </div>
                `;
                $('#contactsContainer').append(newRow);
            });
            
            // Agregar método de pago
            $('#addPayment').click(function() {
                let newRow = `
                    <div class="row payment-entry mb-2">
                        <div class="col-md-5">
                            <input type="text" class="form-control" name="payment_labels[]" placeholder="{{ __('اسم البنك / طريقة الدفع') }}">
                        </div>
                        <div class="col-md-5">
                            <input type="text" class="form-control" name="payment_values[]" placeholder="{{ __('رقم الحساب / معلومات الدفع') }}">
                        </div>
                        <div class="col-md-2">
                            <button type="button" class="btn btn-danger remove-entry"><i class="bi bi-dash-circle"></i></button>
                        </div>
                    </div>
                `;
                $('#paymentsContainer').append(newRow);
            });
            
            // Eliminar entrada
            $(document).on('click', '.remove-entry', function() {
                $(this).closest('.row').remove();
            });
        });

        // Definir eventos para la tabla
        window.userEvents = {
            'click .assign_package': function (e, value, row, index) {
                $('#user_id').val(row.id);
            },
            'click .edit-additional-info': function (e, value, row, index) {
                // Limpiar el formulario
                $('#contactsContainer').html('');
                $('#paymentsContainer').html('');
                
                // Establecer ID de usuario
                $('#info_user_id').val(row.id);
                
                // Rellenar ubicación
                $('#location').val(row.location || '');
                
                // Rellenar contactos adicionales من additional_info
                if (row.additional_info && row.additional_info.contact_info) {
                    try {
                        let contacts = row.additional_info.contact_info;
                        for (let key in contacts) {
                            let newRow = `
                                <div class="row contact-entry mb-2">
                                    <div class="col-md-5">
                                        <input type="text" class="form-control" name="contact_labels[]" value="${key}" placeholder="{{ __('نوع الاتصال (واتساب، تيليجرام، إلخ)') }}">
                                    </div>
                                    <div class="col-md-5">
                                        <input type="text" class="form-control" name="contact_values[]" value="${contacts[key]}" placeholder="{{ __('رقم أو معرف الاتصال') }}">
                                    </div>
                                    <div class="col-md-2">
                                        <button type="button" class="btn btn-danger remove-entry"><i class="bi bi-dash-circle"></i></button>
                                    </div>
                                </div>
                            `;
                            $('#contactsContainer').append(newRow);
                        }
                    } catch (e) {
                        console.error('Error parsing contacts', e);
                    }
                }
                
                // Si no hay contactos, agregar un campo vacío
                if ($('#contactsContainer').children().length === 0) {
                    $('#addContact').click();
                }
                
                // Rellenar información de pago
                if (row.payment_info) {
                    try {
                        let payments = typeof row.payment_info === 'object' ? row.payment_info : JSON.parse(row.payment_info);
                        for (let key in payments) {
                            let newRow = `
                                <div class="row payment-entry mb-2">
                                    <div class="col-md-5">
                                        <input type="text" class="form-control" name="payment_labels[]" value="${key}" placeholder="{{ __('اسم البنك / طريقة الدفع') }}">
                                    </div>
                                    <div class="col-md-5">
                                        <input type="text" class="form-control" name="payment_values[]" value="${payments[key]}" placeholder="{{ __('رقم الحساب / معلومات الدفع') }}">
                                    </div>
                                    <div class="col-md-2">
                                        <button type="button" class="btn btn-danger remove-entry"><i class="bi bi-dash-circle"></i></button>
                                    </div>
                                </div>
                            `;
                            $('#paymentsContainer').append(newRow);
                        }
                    } catch (e) {
                        console.error('Error parsing payment info', e);
                    }
                }
                
                // Si no hay métodos de pago, agregar un campo vacío
                if ($('#paymentsContainer').children().length === 0) {
                    $('#addPayment').click();
                }
                
                // Mostrar el modal
                $('#additionalInfoModal').modal('show');
            }
        };
    </script>
@endsection
