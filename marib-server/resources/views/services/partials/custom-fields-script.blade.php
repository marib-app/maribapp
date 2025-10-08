<script>
(function($){
  $(function(){
    const config = window.__serviceCfConfig || {};
    const TYPES = ['number','textbox','fileinput','radio','dropdown','checkbox','color'];

    function parseSchema(raw){
      if (!raw) return [];
      if (Array.isArray(raw)) return JSON.parse(JSON.stringify(raw));
      if (typeof raw === 'string') {
        try { const parsed = JSON.parse(raw); return Array.isArray(parsed) ? parsed : []; }
        catch(e){ return []; }
      }
      return [];
    }

    const oldValues = config.oldValues || {};
    const existingValues = config.existingValues || {};
    const existingFileUrls = config.existingFileUrls || {};
    const existingIconUrls = config.existingIconUrls || {};
    const existingIconPaths = config.existingIconPaths || {};
    const storageBaseUrl = (config.storageBaseUrl || '').toString().replace(/\/+$/, '');

    let rows = [];

    let editingKey = null;

    const $btnPushField = $('#btn_push_field');
    const $btnCancelEdit = $('#btn_cancel_edit');
    const $builderIconInput = $('#cf_icon');
    const $builderIconPreview = $('#cf_icon_preview');
    const $builderIconClear = $('#cf_icon_clear');
    const addFieldLabel = $btnPushField.length ? $btnPushField.html() : '';
    const updateFieldLabel = '<i class="bi bi-check-circle"></i> {{ __('Update Field') }}';
    const noIconText = @json(__('No icon selected'));

    const initialBuilderIconState = () => ({
      file: null,
      previewUrl: '',
      previewOwned: false,
      storedPath: null,
      cleared: false,
    });
    let builderIconState = initialBuilderIconState();

    function revokeBuilderIconPreview(){
      if (builderIconState.previewOwned && builderIconState.previewUrl) {
        try { URL.revokeObjectURL(builderIconState.previewUrl); } catch (e) {}
      }
      builderIconState.previewUrl = '';
      builderIconState.previewOwned = false;
    }

    function getBuilderIconDisplayUrl(){
      if (builderIconState.file && builderIconState.previewUrl) {
        return builderIconState.previewUrl;
      }
      if (!builderIconState.cleared) {
        if (builderIconState.previewUrl) {
          return builderIconState.previewUrl;
        }
        if (builderIconState.storedPath) {
          return buildStorageUrl(builderIconState.storedPath);
        }
      }
      return '';
    }

    function updateBuilderIconUI(){
      if ($builderIconPreview.length) {
        const displayUrl = getBuilderIconDisplayUrl();
        if (displayUrl) {
          $builderIconPreview.removeClass('text-muted').html(`<img src="${escapeHtml(displayUrl)}" alt="icon" class="img-thumbnail" style="max-width:48px; max-height:48px;">`);
        } else {
          $builderIconPreview.addClass('text-muted').text(noIconText);
        }
      }
      if ($builderIconClear.length) {
        const hasIcon = !!builderIconState.file || (!!builderIconState.storedPath && !builderIconState.cleared);
        $builderIconClear.toggleClass('d-none', !hasIcon);
      }
    }

    function resetBuilderIconState(){
      revokeBuilderIconPreview();
      builderIconState = initialBuilderIconState();
      if ($builderIconInput.length) {
        $builderIconInput.val('');
      }
      updateBuilderIconUI();
    }

    function ensureRowMeta(row){
      if (!row.meta || typeof row.meta !== 'object') {
        row.meta = {};
      } else {
        row.meta = Object.assign({}, row.meta);
      }
      if (row.form_key) {
        row.meta.form_key = row.form_key;
      }
      return row.meta;
    }

    function syncRowMetaIcon(row){
      const meta = ensureRowMeta(row);
      let normalized = null;
      if (row.image === null) {
        normalized = null;
      } else if (typeof row.image === 'string' && row.image.trim() !== '') {
        const clean = normalizeIconPath(row.image);
        normalized = clean && clean.trim() !== '' ? clean : null;
      }
      ['icon','icon_path','image','image_path'].forEach(key => {
        meta[key] = normalized;
      });
    }

    function loadBuilderIconFromRow(row){
      revokeBuilderIconPreview();
      builderIconState = initialBuilderIconState();
      if (row) {
        if (typeof row.image !== 'undefined') {
          if (row.image === null) {
            builderIconState.cleared = true;
            builderIconState.storedPath = null;
          } else if (row.image) {
            builderIconState.storedPath = normalizeIconPath(row.image);
          }
        }
        if (row.__iconFile) {
          builderIconState.file = row.__iconFile;
          if (row.__iconPreviewUrl) {
            builderIconState.previewUrl = row.__iconPreviewUrl;
            builderIconState.previewOwned = false;
          } else {
            try {
              builderIconState.previewUrl = URL.createObjectURL(row.__iconFile);
              builderIconState.previewOwned = true;
            } catch (e) {
              builderIconState.previewUrl = '';
              builderIconState.previewOwned = false;
            }
          }
        } else if (!builderIconState.cleared) {
          const resolved = resolveIconPreview(row);
          if (resolved) {
            builderIconState.previewUrl = resolved;
            builderIconState.previewOwned = false;
          }
        }
      }
      if ($builderIconInput.length) {
        $builderIconInput.val('');
      }
      updateBuilderIconUI();
    }

    function applyBuilderIconToRow(row){
      if (!row) return;
      ensureRowMeta(row);
      if (builderIconState.cleared) {
        revokeIconPreview(row);
        row.__iconFile = null;
        row.image = null;
        row.__iconPreviewUrl = null;
        syncRowMetaIcon(row);
        return;
      }
      if (builderIconState.file) {
        if (row.__iconFile !== builderIconState.file) {
          revokeIconPreview(row);
        }
        row.__iconFile = builderIconState.file;
        if (builderIconState.previewUrl) {
          row.__iconPreviewUrl = builderIconState.previewUrl;
          builderIconState.previewOwned = false;
        }
        if (builderIconState.storedPath !== null && builderIconState.storedPath !== undefined) {
          const normalized = normalizeIconPath(builderIconState.storedPath);
          if (normalized) {
            row.image = normalized;
          }
        } else if (typeof row.image === 'undefined') {
          row.image = null;
        }
      } else if (builderIconState.storedPath !== null && builderIconState.storedPath !== undefined) {
        row.image = normalizeIconPath(builderIconState.storedPath) || null;
      } else if (typeof row.image === 'undefined') {
        row.image = null;
      }
      if (typeof row.image === 'string' && row.image.trim() === '') {
        row.image = null;
      }
      if (!row.__iconFile && !row.image) {
        row.__iconPreviewUrl = null;
      }
      syncRowMetaIcon(row);
    }

    if ($builderIconInput.length) {
      $builderIconInput.on('change', function(){
        const file = this.files && this.files[0] ? this.files[0] : null;
        if (file) {
          revokeBuilderIconPreview();
          builderIconState.file = file;
          builderIconState.cleared = false;
          try {
            builderIconState.previewUrl = URL.createObjectURL(file);
            builderIconState.previewOwned = true;
          } catch (e) {
            builderIconState.previewUrl = '';
            builderIconState.previewOwned = false;
          }
        } else {
          builderIconState.file = null;
          revokeBuilderIconPreview();
          builderIconState.cleared = !builderIconState.storedPath;
        }
        updateBuilderIconUI();
      });
    }

    if ($builderIconClear.length) {
      $builderIconClear.on('click', function(){
        builderIconState.cleared = true;
        builderIconState.file = null;
        builderIconState.storedPath = null;
        revokeBuilderIconPreview();
        if ($builderIconInput.length) {
          $builderIconInput.val('');
        }
        updateBuilderIconUI();
      });
    }



    function sanitizeKey(label){
      label = (label || '').toString();
      if (label === '') return '';
      let normalized = label.normalize('NFKD').replace(/[\u0300-\u036f]/g, '');
      let cleaned;
      try {
        cleaned = normalized.replace(/[^\p{L}\p{N}\s_-]+/gu, '');
      } catch (err) {
        cleaned = normalized.replace(/[^\w\s-\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]+/g, '');
      }

      const slug = cleaned


        .trim()
        .replace(/[\s-]+/g, '_')
        .replace(/_+/g, '_')
        .replace(/^_+|_+$/g, '')

        .toLowerCase();
      return slug || '';
    }

    function ensureUniqueKey(base){
      let key = base || 'field';
      let counter = 1;
      const existingKeys = rows.map(r => r.form_key).filter(Boolean);
      while (existingKeys.includes(key)) {
        key = `${base}_${counter++}`;
      }
      return key;
    }

    function ensureRowKey(row){
      if (row.form_key && row.form_key !== '') return row.form_key;
      const base = sanitizeKey(row.label || row.name || row.handle || row.title || 'field');
      const unique = ensureUniqueKey(base || 'field');
      row.form_key = unique;
      return unique;
    }

    function fieldAliases(row){
      const aliases = [];
      const formKey = ensureRowKey(row);
      if (formKey) aliases.push(formKey);
      const handle = sanitizeKey(row.handle || row.name);
      if (handle && !aliases.includes(handle)) aliases.push(handle);
      const label = sanitizeKey(row.label);
      if (label && !aliases.includes(label)) aliases.push(label);
      if (row.id) aliases.push(String(row.id));
      return aliases;
    }

    function getInitialValue(row){
      const aliases = fieldAliases(row);
      for (const alias of aliases) {
        if (Object.prototype.hasOwnProperty.call(oldValues, alias)) {
          return oldValues[alias];
        }
        if (Object.prototype.hasOwnProperty.call(existingValues, alias)) {
          return existingValues[alias];
        }
      }
      return row.type === 'checkbox' ? [] : '';
    }

    function getExistingFileUrl(row){
      const aliases = fieldAliases(row);
      for (const alias of aliases) {
        if (Object.prototype.hasOwnProperty.call(existingFileUrls, alias)) {
          return existingFileUrls[alias];
        }
      }
      return null;
    }

    function escapeHtml(s){
      return (s || '').toString()
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
    }

    function visibleBuilder(){
      const isChecked = $('#has_custom_fields').is(':checked');
      $('#cf_builder_wrap').toggle(isChecked);
      $('#cf_inputs_wrap').toggle(isChecked && rows.length > 0);
    }

    function renderValueInputs(){
      const show = $('#has_custom_fields').is(':checked') && rows.length > 0;
      const $wrap = $('#cf_inputs_wrap');
      const $container = $('#cf_inputs');
      if (!show) {
        $wrap.hide();
        $container.empty();
        return;
      }
      $wrap.show();
      $container.empty();

      rows.forEach((row, index) => {
        const key = ensureRowKey(row);
        const fieldId = `cf_dynamic_${key}`;
        const label = escapeHtml(row.label || row.title || row.name || `Field ${index+1}`);
        const note = (row.note || '').toString().trim();
        const requiredAttr = row.required ? 'required' : '';
        const value = getInitialValue(row);
        const existingFileUrl = row.type === 'fileinput' ? getExistingFileUrl(row) : null;
        let html = `<div class="col-md-6"><div class="mb-3"><label class="form-label ${row.required ? 'mandatory' : ''}" for="${fieldId}">${label}</label>`;

        switch (row.type) {
          case 'number': {
            const minAttr = row.min ? ` min="${escapeHtml(row.min)}"` : '';
            const maxAttr = row.max ? ` max="${escapeHtml(row.max)}"` : '';
            const val = value === null || value === undefined ? '' : value;
            html += `<input type="number" class="form-control" id="${fieldId}" name="custom_fields[${key}]" value="${escapeHtml(val)}" ${requiredAttr}${minAttr}${maxAttr}>`;
            break;
          }
          case 'textbox': {
            const minAttr = row.min ? ` minlength="${escapeHtml(row.min)}"` : '';
            const maxAttr = row.max ? ` maxlength="${escapeHtml(row.max)}"` : '';
            html += `<input type="text" class="form-control" id="${fieldId}" name="custom_fields[${key}]" value="${escapeHtml(value || '')}" ${requiredAttr}${minAttr}${maxAttr}>`;
            break;
          }
          case 'dropdown': {
            html += `<select id="${fieldId}" name="custom_fields[${key}]" class="form-select" ${requiredAttr}>`;
            html += `<option value="">${escapeHtml('{{ __("Select") }}')}</option>`;
            (row.values || []).forEach(function(opt){
              const optVal = (opt || '').toString();
              const selected = value === optVal ? 'selected' : '';
              html += `<option value="${escapeHtml(optVal)}" ${selected}>${escapeHtml(optVal)}</option>`;
            });
            html += '</select>';
            break;
          }
          case 'radio': {
            (row.values || []).forEach(function(opt, idx){
              const optVal = (opt || '').toString();
              const checked = value === optVal ? 'checked' : '';
              const optId = `${fieldId}_${idx}`;
              html += `<div class="form-check"><input class="form-check-input" type="radio" name="custom_fields[${key}]" id="${optId}" value="${escapeHtml(optVal)}" ${checked} ${idx===0 && row.required ? 'required' : ''}><label class="form-check-label" for="${optId}">${escapeHtml(optVal)}</label></div>`;
            });
            break;
          }
          case 'checkbox': {
            const selectedValues = Array.isArray(value) ? value.map(String) : (value ? [String(value)] : []);
            (row.values || []).forEach(function(opt, idx){
              const optVal = (opt || '').toString();
              const checked = selectedValues.includes(optVal) ? 'checked' : '';
              const optId = `${fieldId}_${idx}`;
              html += `<div class="form-check"><input class="form-check-input" type="checkbox" name="custom_fields[${key}][]" id="${optId}" value="${escapeHtml(optVal)}" ${checked}><label class="form-check-label" for="${optId}">${escapeHtml(optVal)}</label></div>`;
            });
            break;
          }
          case 'color': {
            html += `<select id="${fieldId}" name="custom_fields[${key}]" class="form-select" ${requiredAttr}>`;
            html += `<option value="">${escapeHtml('{{ __("Select") }}')}</option>`;
            (row.colors || row.values || []).forEach(function(opt){
              const optVal = (opt || '').toString().toUpperCase().replace('#','');
              const selected = (value || '').toString().toUpperCase().replace('#','') === optVal ? 'selected' : '';
              const display = `#${optVal}`;
              html += `<option value="${escapeHtml(optVal)}" ${selected}>${escapeHtml(display)}</option>`;
            });
            html += '</select>';
            break;
          }
          case 'fileinput': {
            html += `<input type="file" class="form-control" id="${fieldId}" name="custom_field_files[${key}]" ${requiredAttr}>`;
            if (existingFileUrl) {
              html += `<div class="form-text"><a href="${escapeHtml(existingFileUrl)}" target="_blank">{{ __('View current file') }}</a></div>`;
            }
            break;
          }
          default: {
            html += `<input type="text" class="form-control" id="${fieldId}" name="custom_fields[${key}]" value="${escapeHtml(value || '')}" ${requiredAttr}>`;
          }
        }

        if (note) {
          html += `<div class="form-text text-muted">${escapeHtml(note)}</div>`;
        }

        html += '</div></div>';
        $container.append(html);
      });
    }


    function normalizeIconPath(path){
      if (!path) return '';
      let value = (path || '').toString().trim();
      if (value === '') return '';
      if (storageBaseUrl && value.toLowerCase().startsWith(storageBaseUrl.toLowerCase())) {
        value = value.substring(storageBaseUrl.length);
      }
      value = value.replace(/^\/+/, '');
      if (value.toLowerCase().startsWith('storage/')) {
        value = value.substring('storage/'.length);
      }
      return value;
    }

    function buildStorageUrl(path){
      const clean = normalizeIconPath(path);
      if (!clean) return '';
      if (/^https?:\/\//i.test(path || '')) {
        return path;
      }
      if (storageBaseUrl) {
        return storageBaseUrl + '/' + clean.replace(/^\/+/, '');
      }
      return '/storage/' + clean.replace(/^\/+/, '');
    }

    function ensureRowIcon(row){
      if (typeof row.image === 'undefined' || row.image === null || row.image === '') {
        const aliases = fieldAliases(row);
        for (const alias of aliases) {
          if (Object.prototype.hasOwnProperty.call(existingIconPaths, alias)) {
            const value = normalizeIconPath(existingIconPaths[alias]);
            if (value) {
              row.image = value;
              break;
            }
          }
        }
        if (row.image === undefined) {
          row.image = null;
        }
      } else {
        const normalized = normalizeIconPath(row.image);
        row.image = normalized || null;
      }
    }

    function resolveIconPreview(row){
      if (row.__iconPreviewUrl) {
        return row.__iconPreviewUrl;
      }
      if (row.image) {
        return buildStorageUrl(row.image);
      }
      const aliases = fieldAliases(row);
      for (const alias of aliases) {
        if (Object.prototype.hasOwnProperty.call(existingIconUrls, alias)) {
          return existingIconUrls[alias];
        }
        if (Object.prototype.hasOwnProperty.call(existingIconPaths, alias)) {
          const maybe = buildStorageUrl(existingIconPaths[alias]);
          if (maybe) {
            return maybe;
          }
        }
      }
      return '';
    }

    function refreshIconCell($cell, row, key){
      let $preview = $cell.find('.cf-icon-preview');
      if (!$preview.length) {
        $preview = $('<div class="cf-icon-preview mb-1"></div>');
        $cell.prepend($preview);
      }

      let $input = $cell.find('input.cf-row-icon-input');
      if (!$input.length) {
        $input = $('<input type="file" class="form-control form-control-sm cf-row-icon-input" accept=".jpg,.jpeg,.png,.svg,.webp">');
        $cell.append($input);
      }

      let $clear = $cell.find('.cf-row-icon-clear');
      if (!$clear.length) {
        $clear = $('<button type="button" class="btn btn-sm btn-outline-danger w-100 mt-1 cf-row-icon-clear">{{ __('Remove Icon') }}</button>');
        $cell.append($clear);
      }

      $input.attr('name', `service_field_icons[${key}]`).attr('data-key', key);
      $clear.attr('data-key', key);

      const previewUrl = resolveIconPreview(row);
      if (previewUrl) {
        $preview.html(`<img src="${escapeHtml(previewUrl)}" alt="icon" class="img-thumbnail" style="max-width:48px; max-height:48px;">`);
      } else {
        $preview.html(`<span class="text-muted small">{{ __('No icon') }}</span>`);
      }

      if (row.__iconFile && $input.length && typeof DataTransfer !== 'undefined') {
        try {
          const dataTransfer = new DataTransfer();
          dataTransfer.items.add(row.__iconFile);
          $input[0].files = dataTransfer.files;
        } catch (e) {
          // ignore inability to programmatically set files
        }
      } else if (!row.__iconFile) {
        $input.val('');
      }

    }

    function findRowByKey(key){
      if (!key) return null;
      for (const row of rows) {
        if (ensureRowKey(row) === key) {
          return row;
        }
      }
      return null;
    }

    function revokeIconPreview(row){
      if (row && row.__iconPreviewUrl) {
        URL.revokeObjectURL(row.__iconPreviewUrl);
        row.__iconPreviewUrl = null;
      }
    }

    function renderRows(){

      const $tbody = $('#cf_rows');
      const preservedCells = {};
      $tbody.find('tr[data-key]').each(function(){
        const key = $(this).data('key');
        if (!key) return;
        const $iconCell = $(this).find('td.cf-icon-cell');
        if ($iconCell.length) {
          preservedCells[key] = $iconCell.children().detach();
        }
      });

      $tbody.empty();

      if (!rows.length) {
        $tbody.append(`<tr class="cf-empty"><td colspan="7" class="text-center text-muted">{{ __('No custom fields added yet') }}</td></tr>`);
        renderValueInputs();
        return;
      }

      rows.forEach((r, i) => {
        const isColor = r.type === 'color';
        const valuesText = isColor ? (r.colors || []).map(x => '#' + x).join(', ') : (r.values || []).join(' | ');
        const infoText = valuesText || (r.note || '-');
        ensureRowKey(r);
        ensureRowIcon(r);
        const key = ensureRowKey(r);
        const activeBadge = r.active === false
          ? '<span class="badge bg-secondary">{{ __('Inactive') }}</span>'
          : '<span class="badge bg-success">{{ __('Active') }}</span>';

        const tr = $(`
          <tr data-i="${i}" data-key="${escapeHtml(key)}">
            <td>${escapeHtml(r.label)}</td>
            <td><span class="badge bg-light text-dark">${escapeHtml(r.type)}</span></td>
            <td class="text-center"><input type="checkbox" class="form-check-input cf-row-req" ${r.required ? 'checked' : ''}></td>
            <td class="text-center">${activeBadge}</td>
            <td class="cf-icon-cell-placeholder"></td>

            <td>${escapeHtml(infoText)}</td>
            <td>
              <div class="d-flex gap-2 flex-wrap">
                <button type="button" class="btn btn-sm btn-outline-primary cf-row-edit"><i class="bi bi-pencil"></i></button>
                <button type="button" class="btn btn-sm btn-outline-secondary cf-row-up">↑</button>
                <button type="button" class="btn btn-sm btn-outline-secondary cf-row-down">↓</button>
                <button type="button" class="btn btn-sm btn-outline-danger cf-row-del"><i class="bi bi-x"></i></button>
              </div>
            </td>
          </tr>
        `);
        const $iconCell = $('<td class="cf-icon-cell align-middle"></td>');
        if (preservedCells[key]) {
          $iconCell.append(preservedCells[key]);
        }
        refreshIconCell($iconCell, r, key);
        tr.find('.cf-icon-cell-placeholder').replaceWith($iconCell);

        $tbody.append(tr);
      });

      renderValueInputs();
    }


    $('#cf_rows').on('change', '.cf-row-icon-input', function(){
      const key = $(this).data('key');
      const row = findRowByKey(key);
      if (!row) {
        return;
      }

      const file = this.files && this.files[0] ? this.files[0] : null;
      const $cell = $(this).closest('td.cf-icon-cell');

      if (file) {
        revokeIconPreview(row);
        row.__iconFile = file;

        row.__iconPreviewUrl = URL.createObjectURL(file);
      } else {
        revokeIconPreview(row);
        row.__iconFile = null;
        row.image = null;

      }
      syncRowMetaIcon(row);

      refreshIconCell($cell, row, key);
      syncServiceSchema();
    });

    $('#cf_rows').on('click', '.cf-row-icon-clear', function(){
      const key = $(this).data('key');
      const row = findRowByKey(key);
      if (!row) {
        return;
      }

      const $cell = $(this).closest('td.cf-icon-cell');
      const $input = $cell.find('input.cf-row-icon-input');

      if ($input.length) {
        $input.val('');
      }

      revokeIconPreview(row);
      row.__iconFile = null;
      row.image = null;


      syncRowMetaIcon(row);

      refreshIconCell($cell, row, key);
      syncServiceSchema();
    });


    function rowsChanged(){
      renderRows();
      visibleBuilder();
      syncServiceSchema();
    }



    function normalizeRow(row, index){
      const formKey = ensureRowKey(row);
      const type = (row.type || 'textbox').toLowerCase();
      ensureRowIcon(row);
      const out = {
        title: (row.label || '').toString().trim(),
        label: (row.label || '').toString().trim(),
        name: formKey,
        type: type,
        field_type: type,
        input_type: type,
        required: !!row.required,
        note: (row.note || '').toString().trim(),
        sequence: index + 1,
        active: typeof row.active === 'undefined' ? true : !!row.active,
        status: typeof row.active === 'undefined' ? true : !!row.active,
        meta: Object.assign({}, row.meta || {}, { form_key: formKey })
      };

      if (['radio','dropdown','checkbox'].includes(type)) {
        const vals = (row.values || []).map(v => (v || '').toString()).filter(Boolean);
        if (vals.length) {
          out.values = vals;
          out.options = vals;
          out.choices = vals;
        }
     }
      if (type === 'color') {
        const cols = (row.colors || row.values || []).map(v => (v || '').toString().toUpperCase().replace('#','')).filter(Boolean);
        if (cols.length) {
          out.values = cols;
          out.options = cols;
          out.choices = cols;
        }
 }
      const min = (row.min || '').toString().trim();
      const max = (row.max || '').toString().trim();
      if (type === 'number') {
        if (min) out.min = Number(min);
        if (max) out.max = Number(max);
      } else if (type === 'textbox') {
        if (min) out.min_length = parseInt(min, 10);
        if (max) out.max_length = parseInt(max, 10);
      }

      if (row.id) {
        out.id = row.id;
        
       }

      if (row.image) {
        const normalizedIcon = normalizeIconPath(row.image);
        if (normalizedIcon) {
          out.image = normalizedIcon;
        }
      } else if (row.image === null) {
        out.image = null;
      }

      return out;
    }

    function syncServiceSchema(){
    
    
            if (!$('#has_custom_fields').is(':checked') || !rows.length) {
          $('#service_fields_schema').val('');
          return;
        }
        const normalized = rows.map(normalizeRow);
        $('#service_fields_schema').val(JSON.stringify(normalized));
      }

    function parseExistingSchema(raw){
        const schema = parseSchema(raw);
        if (!schema.length) return [];
        const normType = t => {
          t = (t || '').toString().toLowerCase();
          if (t === 'select') return 'dropdown';
          if (t === 'file' || t === 'image') return 'fileinput';
          if (t === 'textarea') return 'textbox';
          return TYPES.includes(t) ? t : 'textbox';
        };

        return schema.map(field => {
          const type = normType(field.type || field.field_type || field.input_type || 'textbox');
          const values = Array.isArray(field.values) ? field.values : (Array.isArray(field.options) ? field.options : (Array.isArray(field.choices) ? field.choices : []));
          const colorValues = type === 'color' ? values.map(v => (v || '').toString().toUpperCase().replace('#','')).filter(Boolean) : [];
          const aliases = [
            field.form_key,
            field.name,
            field.handle,
            field.key,
            field.label,
            field.title,
            field?.meta?.form_key ?? null,
          ];
          const imagePath = normalizeIconPath(field.image || field.image_path || field.icon || '');


          const row = {
            label: (field.label || field.title || field.name || '').toString(),
            type,
            required: !!field.required,
            note: (field.note || '').toString(),
            values: type === 'color' ? [] : (values || []).map(v => (v || '').toString()),
            colors: colorValues,
            min: field.min_length ?? field.min ?? '',
            max: field.max_length ?? field.max ?? '',
            active: typeof field.active === 'undefined' ? (typeof field.status === 'undefined' ? true : !!field.status) : !!field.active,
            meta: field.meta || {},
            id: field.id ?? null,
            form_key: null,
            image: imagePath || null,


          };
          for (const alias of aliases) {
            const key = sanitizeKey(alias);
            if (key) {
              row.form_key = key;
              break;
            }
          }
          return row;
        });
      }

    rows = parseExistingSchema(config.schema);
    rowsChanged();


    $('#has_custom_fields').on('change', function(){
      visibleBuilder();
      renderValueInputs();
      syncServiceSchema();


    });

    if ($.fn.select2) {
      $('#cf_values').select2({ tags: true, width: '100%' });
    }

    function onTypeChange() {
      const t = $('#cf_type').val();
      if (['checkbox','radio','dropdown'].includes(t)) {
        $('#field-values-div').slideDown(200);
        $('#color-picker-div').slideUp(200);
        $('.min-max-fields').slideUp(200);
      } else if (t === 'color') {
        $('#color-picker-div').slideDown(200);
        $('#field-values-div').slideUp(200);
        $('.min-max-fields').slideUp(200);
      } else {
        $('#field-values-div').slideUp(200);
        $('#color-picker-div').slideUp(200);
        $('.min-max-fields').slideDown(200);
  
      }
   }


    $('#cf_type').on('change', onTypeChange);
    onTypeChange();

    function updateColorValues() {
      const colors = [];
      $('.color-hex').each(function(){
        let hex = ($(this).val() || '').replace('#','').trim();
        if (/^[0-9A-Fa-f]{6}$/.test(hex)) {
          colors.push(hex.toUpperCase());
        }
      });
      $('#cf_color_values').val(JSON.stringify(colors));
    }


    function parseColorValues() {
      const raw = ($('#cf_color_values').val() || '').toString();
      if (!raw) return [];
      try {
        const parsed = JSON.parse(raw);
        if (Array.isArray(parsed)) {
          return parsed
            .map(v => (v || '').toString().toUpperCase().replace('#','').trim())
            .filter(Boolean);
        }
      } catch (e) {
        return [];
      }
      return [];
    }


    function setColorInputs(colors){
      const $container = $('#color-container');
      if (!$container.length) {
        return;
      }
      $container.empty();
      const list = (Array.isArray(colors) && colors.length) ? colors : ['FF0000'];
      list.forEach(function(color){
        let hex = (color || 'FF0000').toString().replace('#','').toUpperCase();
        if (!/^[0-9A-F]{6}$/.test(hex)) {
          hex = 'FF0000';
        }
        const group = `
          <div class="color-input-group mb-2">
            <input type="color" class="form-control color-picker" value="#${hex}">
            <input type="text" class="form-control color-hex" placeholder="#${hex}" value="${hex}">
            <button type="button" class="btn btn-danger remove-color">×</button>
          </div>`;
        $container.append(group);
      });
      updateColorValues();
    }


    function collectBuilderFormData(){
      const label = ($('#cf_name').val() || '').toString().trim();
      if (!label) {
        return null;
      }
      const type = ($('#cf_type').val() || 'textbox').toString();
      const note = ($('#cf_note').val() || '').toString().trim();
      const required = $('#cf_required').is(':checked');
      const active = $('#cf_active').is(':checked');
      let min = '';
      let max = '';
      if (type === 'number' || type === 'textbox') {
        min = ($('#cf_min').val() || '').toString().trim();
        max = ($('#cf_max').val() || '').toString().trim();
      }
      let values = [];
      let colors = [];
      if (['checkbox','radio','dropdown'].includes(type)) {
        values = (($('#cf_values').val() || [])).map(v => (v || '').toString().trim()).filter(Boolean);
      } else if (type === 'color') {
        colors = parseColorValues();
      }
      return { label, type, note, required, active, min, max, values, colors };
    }


    function resetBuilderForm(){

      editingKey = null;
      if ($btnPushField.length) {
        $btnPushField.html(addFieldLabel);
      }
      if ($btnCancelEdit.length) {
        $btnCancelEdit.addClass('d-none');
      }

      $('#cf_name').val('');
      $('#cf_type').val('textbox').trigger('change');
      $('#cf_min, #cf_max').val('');
      $('#cf_note').val('');
      $('#cf_required').prop('checked', false);
      $('#cf_active').prop('checked', true);
      const $values = $('#cf_values');
      if ($values.length) {
        $values.val(null).trigger('change');
      }
      setColorInputs(['FF0000']);
      resetBuilderIconState();
    }

    function startEditRow(index){
      if (!Number.isInteger(index) || !rows[index]) {
        return;
      }
      const row = rows[index];
      ensureRowKey(row);
      ensureRowIcon(row);
      editingKey = ensureRowKey(row);
      if ($btnPushField.length) {
        $btnPushField.html(updateFieldLabel);
      }
      if ($btnCancelEdit.length) {
        $btnCancelEdit.removeClass('d-none');
      }
      $('#cf_name').val(row.label || '');
      const type = (row.type || 'textbox').toString();
      $('#cf_type').val(type).trigger('change');
      if (type === 'number' || type === 'textbox') {
        $('#cf_min').val(row.min || '');
        $('#cf_max').val(row.max || '');
      } else {
        $('#cf_min').val('');
        $('#cf_max').val('');
      }
      $('#cf_note').val(row.note || '');
      $('#cf_required').prop('checked', !!row.required);
      $('#cf_active').prop('checked', row.active !== false);
      const $values = $('#cf_values');
      if ($values.length) {
        if (['checkbox','radio','dropdown'].includes(type)) {
          const opts = (row.values || []).map(v => (v || '').toString());
          $values.val(opts).trigger('change');
        } else {
          $values.val(null).trigger('change');
        }
      }
      if (type === 'color') {
        const colors = (row.colors || []).length ? row.colors : ['FF0000'];
        setColorInputs(colors);
      } else {
        setColorInputs(['FF0000']);
      }
      loadBuilderIconFromRow(row);
      if ($('#cf_builder_wrap').length) {
        const offsetTop = $('#cf_builder_wrap').offset().top - 100;
        $('html, body').animate({ scrollTop: offsetTop }, 200);

      }
    }

    if ($btnCancelEdit.length) {
      $btnCancelEdit.on('click', function(){
        resetBuilderForm();
      });
    }

    function moveRow(index, delta){
      const newIndex = index + delta;
      if (newIndex < 0 || newIndex >= rows.length) {
        return;
      }
      const [row] = rows.splice(index, 1);
      rows.splice(newIndex, 0, row);
      rowsChanged();
    }






    $('#add-color').on('click', function(){
      const grp = `
        <div class="color-input-group mb-2">
          <input type="color" class="form-control color-picker" value="#FF0000">
          <input type="text" class="form-control color-hex" placeholder="#FF0000" value="FF0000">
          <button type="button" class="btn btn-danger remove-color">×</button>
        </div>`;
      $('#color-container').append(grp);
      updateColorValues();
    });

    $(document).on('click', '.remove-color', function(){
      if ($('.color-input-group').length > 1) {
        $(this).closest('.color-input-group').remove();


        updateColorValues();
      }
    });
    $(document).on('change', '.color-picker', function(){
      const hex = ($(this).val() || '').substring(1);
      $(this).siblings('.color-hex').val(hex);
      updateColorValues();
    });



    $(document).on('input', '.color-hex', function(){
      let hex = ($(this).val() || '').replace('#','');
      if (hex.length === 6 && /^[0-9A-Fa-f]{6}$/.test(hex)) {
        $(this).siblings('.color-picker').val('#' + hex);
      }
      updateColorValues();
    });
    updateColorValues();


    $('#btn_push_field').on('click', function(){
       const data = collectBuilderFormData();
      if (!data) {
        $('#cf_name').focus();
        return;
      }

      const applyCommonData = function(row){
        row.label = data.label;
        row.type = data.type;
        row.required = data.required;
        row.note = data.note;
        if (data.type === 'number' || data.type === 'textbox') {
          row.min = data.min;
          row.max = data.max;
        } else {
          row.min = '';
          row.max = '';
        }
        row.values = ['checkbox','radio','dropdown'].includes(data.type) ? data.values.slice() : [];
        row.colors = data.type === 'color' ? data.colors.slice() : [];
        row.active = data.active;
      };

      const existingRow = editingKey ? findRowByKey(editingKey) : null;


      if (existingRow) {
        const row = existingRow;
        applyCommonData(row);
        ensureRowKey(row);
        ensureRowMeta(row);
        applyBuilderIconToRow(row);
        ensureRowMeta(row);
        rowsChanged();
      } else {
        const row = {
          label: data.label,
          type: data.type,
          required: data.required,
          note: data.note,
          min: (data.type === 'number' || data.type === 'textbox') ? data.min : '',
          max: (data.type === 'number' || data.type === 'textbox') ? data.max : '',
          values: ['checkbox','radio','dropdown'].includes(data.type) ? data.values.slice() : [],
          colors: data.type === 'color' ? data.colors.slice() : [],
          active: data.active,
          meta: {},
          image: null,
          __iconFile: builderIconState.file || null,
          __iconPreviewUrl: builderIconState.previewUrl || null,
        };
        ensureRowKey(row);
        ensureRowMeta(row);
        applyBuilderIconToRow(row);
        ensureRowMeta(row);
        rows.push(row);
        rowsChanged();
      }


      resetBuilderForm();
    });

    $('#btn_clear_fields').on('click', function(){
      if (!rows.length) {
        return;
      }
      rows.forEach(revokeIconPreview);


      rows = [];
      rowsChanged();
      resetBuilderForm();
    });

    $('#cf_rows').on('click', '.cf-row-edit', function(){
      const index = Number($(this).closest('tr').data('i'));
      if (!Number.isInteger(index)) {
        return;
      }
      startEditRow(index);

    });

    $('#cf_rows').on('click', '.cf-row-del', function(){
      const index = Number($(this).closest('tr').data('i'));
      if (!Number.isInteger(index)) {
        return;
      }
      const row = rows[index];
      if (row) {
        const key = ensureRowKey(row);
        revokeIconPreview(row);
        rows.splice(index, 1);
        if (editingKey && key === editingKey) {
          resetBuilderForm();
        }


      }

      rowsChanged();
    });

    $('#cf_rows').on('click', '.cf-row-up', function(){
      const index = Number($(this).closest('tr').data('i'));
      if (!Number.isInteger(index)) {
        return;
      }
      moveRow(index, -1);
    });

    $('#cf_rows').on('click', '.cf-row-down', function(){
      const index = Number($(this).closest('tr').data('i'));
      if (!Number.isInteger(index)) {
        return;
      }
      moveRow(index, 1);
    });

    $('#cf_rows').on('change', '.cf-row-req', function(){
      const index = Number($(this).closest('tr').data('i'));
      if (!Number.isInteger(index) || !rows[index]) {
        return;
      }
      const checked = $(this).is(':checked');
      rows[index].required = checked;
      if (typeof rows[index].active === 'undefined') {
        rows[index].active = true;
      }
      rowsChanged();
    });



    $('#serviceForm').on('form:beforeAjax', syncServiceSchema);
    $('#serviceForm').on('submit', function(){ syncServiceSchema(); });
  });




})(jQuery);
</script>

<style>
.color-input-group { display:flex; gap:10px; align-items:center; }
.color-input-group .form-control { flex:1; }
.color-input-group .color-picker { width:60px; height:40px; padding:2px; border-radius:5px; }
.color-input-group .remove-color { width:40px; height:40px; display:flex; align-items:center; justify-content:center; }

.cf-icon-preview { min-height:52px; display:flex; align-items:center; justify-content:flex-start; }
.cf-icon-preview img { max-width:48px; max-height:48px; object-fit:contain; }
</style>
  