<div id="editStatusModal" class="modal fade" tabindex="-1" role="dialog" aria-labelledby="editStatusModalLabel" aria-hidden="true">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title" id="editStatusModalLabel">{{ __('Status') }}</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="{{ __('Close') }}"></button>
            </div>
            <div class="modal-body">
                <form class="edit-form" action="" method="POST" data-success-function="updateApprovalSuccess">
                    @csrf
                    <div class="row g-3">
                        <div class="col-12">
                            <label for="status" class="form-label">{{ __('Status') }}</label>
                            <select name="status" class="form-select" id="status" aria-label="{{ __('Status') }}">
                                <option value="review">{{ __('Under Review') }}</option>
                                <option value="approved">{{ __('Approve') }}</option>
                                <option value="rejected">{{ __('Reject') }}</option>
                            </select>
                        </div>
                        <div class="col-12" id="rejected_reason_container" style="display: none;">
                            <label for="rejected_reason" class="mandatory form-label">{{ __('Reason') }}</label>
                            <textarea name="rejected_reason" id="rejected_reason" class="form-control" placeholder="{{ __('Reason') }}"></textarea>
                        </div>
                    </div>
                    <div class="mt-4 d-flex justify-content-end gap-2">
                        <button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">{{ __('Cancel') }}</button>
                        <button type="submit" class="btn btn-primary">{{ __('Save') }}</button>
                    </div>
                </form>
            </div>
        </div>
    </div>
</div>