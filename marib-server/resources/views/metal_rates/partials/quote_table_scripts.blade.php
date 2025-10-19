@push('scripts')
    <script>
        document.addEventListener('DOMContentLoaded', function () {
            const tables = document.querySelectorAll('.quotes-table');

            tables.forEach(function (table) {
                const radios = table.querySelectorAll('.default-governorate-radio');

                if (!Array.from(radios).some((radio) => radio.checked) && radios.length) {
                    radios[0].checked = true;
                }

                table.addEventListener('change', function (event) {
                    const target = event.target;
                    if (!target.classList.contains('default-governorate-radio')) {
                        return;
                    }

                    radios.forEach(function (radio) {
                        if (radio !== target) {
                            radio.checked = false;
                        }
                    });
                });
            });
        });
    </script>
@endpush