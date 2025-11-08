<?php

namespace App\Http\Controllers;

use App\Models\Blog;
use App\Models\Category;
use App\Models\Item;
use App\Models\Slider;
use App\Services\InterfaceSectionService;
use App\Models\Service;
use App\Models\User;
use App\Models\SliderDefault;
use App\Services\SliderDefaultService;

use App\Services\BootstrapTableService;
use App\Services\FileService;
use App\Services\ResponseService;
use Illuminate\Http\Request;
use App\Services\SliderMetricService;
use Carbon\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

use Throwable;

class SliderController extends Controller {

    private string $uploadFolder;

    public function __construct(
        private SliderMetricService $sliderMetricService,
        private SliderDefaultService $sliderDefaultService
    ) {
        
        $this->uploadFolder = 'sliders';
    }

    public function index() {
        ResponseService::noAnyPermissionThenRedirect(['slider-list', 'slider-create', 'slider-update', 'slider-delete']);
        $slider = Slider::select(['id', 'image', 'sequence'])->orderBy('sequence', 'ASC')->get();
        $interfaceData = $this->buildInterfaceData();
        $sliderDefaults = $this->sliderDefaultService->listActiveDefaults();

        $reportEnd = Carbon::now()->endOfDay();
        $reportStart = Carbon::now()->copy()->subDays(29)->startOfDay();

        $dailyMetrics = $this->sliderMetricService->getDailyAggregates($reportStart, $reportEnd);
        $weeklyMetrics = $this->sliderMetricService->getWeeklyAggregates($reportStart, $reportEnd);
        $statusMetricsRaw = $this->sliderMetricService->getStatusAggregates($reportStart, $reportEnd);
        $interfaceMetricsRaw = $this->sliderMetricService->getInterfaceTypeAggregates($reportStart, $reportEnd);
        $availableStatuses = Slider::availableStatuses();

        $statusMetrics = $this->buildStatusMetrics($statusMetricsRaw);
        $interfaceMetrics = $this->buildInterfaceMetrics($interfaceMetricsRaw);
        $sliderStatusLabels = $this->buildSliderStatusLabels($availableStatuses);

        return view('slider.index', array_merge($interfaceData, [
            'slider'               => $slider,
            'sliderStatusLabels'   => $sliderStatusLabels,
            'reportDefaultStart'   => $reportStart->toDateString(),
            'reportDefaultEnd'     => $reportEnd->toDateString(),
            'dailyMetrics'         => $dailyMetrics->values()->all(),
            'weeklyMetrics'        => $weeklyMetrics->values()->all(),
            'statusMetrics'        => $statusMetrics->all(),
            'interfaceMetrics'     => $interfaceMetrics->all(),
            'sliderDefaults'       => $sliderDefaults,

        ]));

    }

    public function create() {
        ResponseService::noPermissionThenRedirect('slider-create');

        $formData = array_merge(
            $this->buildInterfaceData(),
            $this->buildFormDatasets()
        );

        return view('slider.create', $formData);
    }



    public function createDefault()
    {
        ResponseService::noPermissionThenRedirect('slider-create');

        return view('slider.defaults.create', array_merge($this->buildInterfaceData(), [
            'sliderDefaults' => $this->sliderDefaultService->listDefaults(),
        ]));
    }

    public function storeDefault(Request $request)
    {
        ResponseService::noPermissionThenRedirect('slider-create');

        $allowedInterfaceTypes = array_values(array_unique(array_merge(
            ['all'],
            InterfaceSectionService::allowedSectionTypes(true)
        )));

        $validator = Validator::make($request->all(), [
            'interface_type' => ['required', 'string', Rule::in($allowedInterfaceTypes)],
            'image'          => ['required', 'image', 'max:5120'],
        ]);

        if ($validator->fails()) {
            return redirect()->back()->withErrors($validator)->withInput();
        }

        $data = $validator->validated();

        $this->sliderDefaultService->upsert($data['interface_type'], $request->file('image'));

        return redirect()->route('slider.index')->with('success', __('طھظ… ط­ظپط¸ ط§ظ„طµظˆط±ط© ط§ظ„ط§ظپطھط±ط§ط¶ظٹط© ط¨ظ†ط¬ط§ط­.'));
    }

    public function destroyDefault(SliderDefault $sliderDefault)
    {
        ResponseService::noPermissionThenRedirect('slider-delete');

        $this->sliderDefaultService->delete($sliderDefault);

        return redirect()->route('slider.index')->with('success', __('طھظ… ط­ط°ظپ ط§ظ„طµظˆط±ط© ط§ظ„ط§ظپطھط±ط§ط¶ظٹط©.'));
    }

    private function buildInterfaceData(): array {
        $allowedInterfaceTypes = array_values(InterfaceSectionService::allowedSectionTypes());

        $defaultInterfaceType = InterfaceSectionService::defaultSectionType() ?? ($allowedInterfaceTypes[0] ?? null);
        $interfaceTypeLabels = $this->buildInterfaceTypeLabels();
        $interfaceTypeOptions = array_values(array_unique(array_merge(['all'], $allowedInterfaceTypes)));
        $sliderAliasMap = collect(InterfaceSectionService::sectionTypeAliases() ?? config('interface_sections.section_type_aliases', []))
            ->mapWithKeys(fn ($value, $key) => [Str::lower($key) => $value])
            ->toArray();

        return [
            'allowedInterfaceTypes' => $allowedInterfaceTypes,
            'defaultInterfaceType'  => $defaultInterfaceType,
            'interfaceTypeLabels'   => $interfaceTypeLabels,
            'interfaceTypeOptions'  => $interfaceTypeOptions,
            'sliderAliasMap'        => $sliderAliasMap,
        ];
    }

    private function buildFormDatasets(): array {
        $targetTypeLabels = [
            'item'     => __('ظ…ظ†طھط¬'),
            'category' => __('ظپط¦ط©'),
            'blog'     => __('طµظپط­ط©'),
            'user'     => __('ظ…ط³طھط®ط¯ظ…'),
            'service'  => __('ط®ط¯ظ…ط©'),
        ];

        $actionTypeLabels = [
            Slider::ACTION_OPEN_CHAT    => __('ظپطھط­ ط¯ط±ط¯ط´ط©'),
            Slider::ACTION_APPLY_COUPON => __('طھط·ط¨ظٹظ‚ ظƒظˆط¨ظˆظ†'),
            Slider::ACTION_OPEN_LINK    => __('ط±ط§ط¨ط· ظ…ط®طµطµ'),
        ];

        $sliderStatuses = Slider::availableStatuses();

        return [
            'items'               => Item::where('status', 'approved')->get(),
            'categories'          => Category::where('status', 1)->get(),
            'blogs'               => Blog::all(),
            'users'               => User::query()->select(['id', 'name'])->orderBy('name')->limit(200)->get(),
            'services'            => Service::query()->select(['id', 'title as name'])->orderBy('title')->limit(200)->get(),
            'sliderStatuses'      => $sliderStatuses,
            'targetTypeOptions'   => Slider::availableTargetTypes(),
            'targetTypeLabels'    => $targetTypeLabels,
            'actionTypeOptions'   => Slider::availableActionTypes(),
            'actionTypeLabels'    => $actionTypeLabels,
            'sliderStatusLabels'  => $this->buildSliderStatusLabels($sliderStatuses),
        ];
    }
    private function buildInterfaceTypeLabels(): array {
        return [
            'all'                     => __('ط§ظ„ظƒظ„'),
            'homepage'                => __('ط§ظ„طµظپط­ط© ط§ظ„ط±ط¦ظٹط³ظٹط©'),
            'real_estate'             => __('ط§ظ„ط®ط¯ظ…ط§طھ ط§ظ„ط¹ظ‚ط§ط±ظٹط©'),
            'tourism'                 => __('ط§ظ„ط®ط¯ظ…ط§طھ ط§ظ„ط³ظٹط§ط­ظٹط©'),
            'merchants'               => __('ط§ظ„ظ…طھط¬ط± ط§ظ„ط¥ظ„ظƒطھط±ظˆظ†ظٹ'),
            'shein'                   => __('ظ…ظ†طھط¬ط§طھ ط´ظٹ ط¥ظ†'),
            'computer'                => __('ظ‚ط³ظ… ط§ظ„ظƒظ…ط¨ظٹظˆطھط±'),
            'public'                  => __('ط¥ط¹ظ„ط§ظ†ط§طھ ط§ظ„ط¬ظ…ظ‡ظˆط±'),
            'request_ad'              => __('ط·ظ„ط¨ ط¥ط¹ظ„ط§ظ†'),
            'services_all'            => __('ظƒظ„ ط§ظ„ط®ط¯ظ…ط§طھ'),
            'services_local'          => __('ط®ط¯ظ…ط§طھ ظ…ط­ظ„ظٹط©'),
            'services_medical'        => __('ط®ط¯ظ…ط§طھ ط·ط¨ظٹط©'),
            'services_jobs'           => __('ظˆط¸ط§ط¦ظپ'),
            'services_events_offers'  => __('ظپط¹ط§ظ„ظٹط§طھ ظˆط¹ط±ظˆط¶'),
            'services_marib_lost'     => __('ظ…ظپظ‚ظˆط¯ط§طھ ظ…ط§ط±ط¨'),
            'services_student'        => __('ط®ط¯ظ…ط§طھ ط·ظ„ط§ط¨ظٹط©'),
            'services_marib_guide'    => __('ط¯ظ„ظٹظ„ ظ…ط§ط±ط¨'),
        ];
    }


    private function buildSliderStatusLabels(array $availableStatuses): array {
        return collect($availableStatuses)
        
        ->mapWithKeys(fn (string $status) => [
                $status => __(ucwords(str_replace('_', ' ', $status))),
            ])
            ->toArray();
    
    }

    public function store(Request $request) {

        ResponseService::noPermissionThenRedirect('slider-create');

        $input = $request->all();
        $normalizeSelection = static function ($value) {
            if (! is_string($value)) {
                return $value ?: null;
            }

            $value = trim($value);

            if ($value === '' || strtolower($value) === 'none') {
                return null;
            }

            return $value;
        };

        $input['target_type'] = $normalizeSelection($input['target_type'] ?? null);
        $input['action_type'] = $normalizeSelection($input['action_type'] ?? null);

        if (empty($input['target_type'])) {
            if (! empty($input['item'])) {
                $input['target_type'] = 'item';
                $input['target_id'] = $input['item'];
            } elseif (! empty($input['category_id'])) {
                $input['target_type'] = 'category';
                $input['target_id'] = $input['category_id'];
            } elseif (! empty($input['blog_id'])) {
                $input['target_type'] = 'blog';
                $input['target_id'] = $input['blog_id'];
            }


        }

        foreach (['action_link_url', 'link'] as $linkField) {
            if (isset($input[$linkField]) && is_string($input[$linkField])) {
                $input[$linkField] = trim($input[$linkField]);

                if ($input[$linkField] === '') {
                    $input[$linkField] = null;
                }
            }
        }

        if (! $input['target_type']) {
            $input['target_id'] = null;
        }

        $validator = Validator::make($input, [

            
            'image.*'                     => 'required|image|mimes:jpg,png,jpeg|max:2048',
            'status'                      => 'required|in:' . implode(',', Slider::availableStatuses()),
            'priority'                    => 'nullable|integer|min:0',
            'weight'                      => 'nullable|integer|min:1',
            'share_of_voice'              => 'nullable|numeric|min:0|max:100',
            'starts_at'                   => 'nullable|date',
            'ends_at'                     => 'nullable|date|after_or_equal:starts_at',
            'dayparting_json'             => 'nullable',
            'per_user_per_day_limit'      => 'nullable|integer|min:1',
            'per_user_per_session_limit'  => 'nullable|integer|min:1',
            'target_type'                 => ['nullable', 'string', Rule::in(Slider::availableTargetTypes())],
            'target_id'                   => ['nullable', 'integer', 'min:1', 'required_with:target_type'],
            'action_type'                 => ['nullable', 'string', Rule::in(Slider::availableActionTypes())],
            'action_coupon_code'          => ['nullable', 'string', 'max:255'],
            'action_coupon_label'         => ['nullable', 'string', 'max:255'],
            'action_coupon_description'   => ['nullable', 'string', 'max:500'],
            'action_link_url'             => ['nullable', 'url', 'max:2048'],
            'action_link_title'           => ['nullable', 'string', 'max:255'],
            'action_chat_user_id'         => ['nullable', 'integer', 'min:1'],


        ]);
        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }

        $targetTypeAlias = $input['target_type'] ?? null;
        $targetId = isset($input['target_id']) ? (int) $input['target_id'] : null;
        $actionType = $input['action_type'] ?? null;

        $linkUrl = $input['action_link_url'] ?? $input['link'] ?? null;
        if (is_string($linkUrl)) {
            $linkUrl = trim($linkUrl);
        }
        if ($linkUrl === '') {
            $linkUrl = null;
        }

        $hasTarget = $targetTypeAlias && $targetId;
        $hasAction = ! empty($actionType);
        $hasLink = ! empty($linkUrl);

        if (! $hasTarget && ! $hasAction && ! $hasLink) {
            ResponseService::validationError(__('ظٹط±ط¬ظ‰ طھط­ط¯ظٹط¯ ظˆط¬ظ‡ط© ط£ظˆ ط¥ط¬ط±ط§ط، ط£ظˆ ط±ط§ط¨ط· ظ„ظ„ط³ظ„ط§ظٹط¯ط±.'));
        }

        try {

            $lastSequence = Slider::max('sequence');
            $nextSequence = $lastSequence + 1;
            $rawInterfaceType = $request->input('interface_type');
            $defaultInterfaceType = InterfaceSectionService::defaultSectionType();

            if ($defaultInterfaceType === null) {
                $availableInterfaceTypes = InterfaceSectionService::allowedSectionTypes();
                $defaultInterfaceType = $availableInterfaceTypes[0] ?? null;
            }

            $interfaceType = $rawInterfaceType === 'all'
                ? 'all'
                : InterfaceSectionService::normalizeSectionType($rawInterfaceType ?? $defaultInterfaceType);



            $dayparting = $request->input('dayparting_json');
            if (is_string($dayparting)) {
                $dayparting = trim($dayparting);
            }

            if (! empty($dayparting) && ! is_array($dayparting)) {
                $decodedDayparting = json_decode($dayparting, true);
                if (json_last_error() !== JSON_ERROR_NONE) {
                    ResponseService::validationError(__('طµظٹط؛ط© ط§ظ„طھظ‚ط³ظٹظ… ط§ظ„ط²ظ…ظ†ظٹ ط؛ظٹط± طµط­ظٹط­ط©. ظٹط±ط¬ظ‰ ط§ط³طھط®ط¯ط§ظ… JSON طµط§ظ„ط­.'));
                }
                $dayparting = $decodedDayparting;
            }

            if (empty($dayparting)) {
                $dayparting = null;
            }

            $targetModel = null;
            $targetClass = null;
            if ($targetTypeAlias && $targetId) {
                $targetMap = Slider::targetTypeMap();
                $targetClass = $targetMap[$targetTypeAlias] ?? null;

                if (! $targetClass) {
                    ResponseService::validationError(__('ظ†ظˆط¹ ط§ظ„ظˆط¬ظ‡ط© ط§ظ„ظ…ط­ط¯ط¯ ط؛ظٹط± طµط§ظ„ط­.'));
                }

                $targetModel = $targetClass::find($targetId);

                if (! $targetModel) {
                    ResponseService::validationError(__('ط§ظ„ط¹ظ†طµط± ط§ظ„ظ…ط­ط¯ط¯ ط؛ظٹط± ظ…ظˆط¬ظˆط¯.'));
                }
            }

            $actionPayload = null;

            if ($actionType === Slider::ACTION_OPEN_CHAT) {
                $chatUserId = isset($input['action_chat_user_id']) ? (int) $input['action_chat_user_id'] : null;

                if (! $chatUserId && $targetModel instanceof User) {
                    $chatUserId = $targetModel->getKey();
                }

                if (! $chatUserId) {
                    ResponseService::validationError(__('ظٹط±ط¬ظ‰ ط§ط®طھظٹط§ط± ظ…ط³طھط®ط¯ظ… طµط§ظ„ط­ ظ„ط¨ط¯ط، ط§ظ„ط¯ط±ط¯ط´ط©.'));
                }

                $chatUser = User::find($chatUserId);

                if (! $chatUser) {
                    ResponseService::validationError(__('ط§ظ„ظ…ط³طھط®ط¯ظ… ط§ظ„ظ…ط­ط¯ط¯ ط؛ظٹط± ظ…ظˆط¬ظˆط¯.'));
                }

                $actionPayload = ['chat_with' => $chatUser->getKey()];

                if (! $targetModel) {
                    $targetModel = $chatUser;
                    $targetTypeAlias = 'user';
                    $targetClass = User::class;
                }
            } elseif ($actionType === Slider::ACTION_APPLY_COUPON) {
                $couponCode = isset($input['action_coupon_code']) ? trim((string) $input['action_coupon_code']) : '';

                if ($couponCode === '') {
                    ResponseService::validationError(__('ظٹط±ط¬ظ‰ ط¥ط¯ط®ط§ظ„ ط±ظ…ط² ط§ظ„ظƒظˆط¨ظˆظ†.'));
                }

                $actionPayload = array_filter([
                    'code'        => $couponCode,
                    'label'       => isset($input['action_coupon_label']) ? trim((string) $input['action_coupon_label']) : null,
                    'description' => isset($input['action_coupon_description']) ? trim((string) $input['action_coupon_description']) : null,
                ], static fn ($value) => $value !== null && $value !== '');
            } elseif ($actionType === Slider::ACTION_OPEN_LINK) {
                if (! $linkUrl) {
                    ResponseService::validationError(__('ظٹط±ط¬ظ‰ ط¥ط¯ط®ط§ظ„ ط±ط§ط¨ط· طµط§ظ„ط­.'));
                }

                $actionPayload = array_filter([
                    'url'   => $linkUrl,
                    'title' => isset($input['action_link_title']) ? trim((string) $input['action_link_title']) : null,
                ], static fn ($value) => $value !== null && $value !== '');
            }

            if ($targetTypeAlias && ! $targetModel) {
                ResponseService::validationError(__('ط§ظ„ط¹ظ†طµط± ط§ظ„ظ…ط­ط¯ط¯ ط؛ظٹط± ظ…ظˆط¬ظˆط¯.'));
            }

            $targetTypeMorph = $targetModel?->getMorphClass();
            $targetIdValue = $targetModel?->getKey();



            $slider = Slider::create([
                'image'                       => $request->hasFile('image') ? FileService::compressAndUpload($request->file('image'), $this->uploadFolder) : '',
                'third_party_link'            => $linkUrl ?? '',
                'sequence'                    => $nextSequence,
                'interface_type'              => $interfaceType,
                'priority'                    => $request->integer('priority') ?? 0,
                'weight'                      => $request->integer('weight') ?? 1,
                'share_of_voice'              => $request->input('share_of_voice', 0),
                'status'                      => $request->input('status', Slider::STATUS_ACTIVE),
                'starts_at'                   => $request->input('starts_at'),
                'ends_at'                     => $request->input('ends_at'),
                'dayparting_json'             => $dayparting,
                'per_user_per_day_limit'      => $request->integer('per_user_per_day_limit') ?: null,
                'per_user_per_session_limit'  => $request->integer('per_user_per_session_limit') ?: null,
                'target_type'                 => $targetTypeMorph,
                'target_id'                   => $targetIdValue,
                'action_type'                 => $actionType,
                'action_payload'              => $actionPayload ?: null,

            ]);


            if ($targetModel) {
                $slider->target()->associate($targetModel);
                $slider->model()->associate($targetModel);
                if ($slider->isDirty()) {
                    $slider->save();
                }
                $slider->setRelation('target', $targetModel);
                $slider->setRelation('model', $targetModel);


            }
            ResponseService::successResponse('Slider created successfully');
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "Slider Controller -> store");
            ResponseService::errorResponse();
        }
    }

    public function destroy($id) {
        ResponseService::noPermissionThenRedirect('slider-delete');
        try {
            $slider = Slider::find($id);
            if ($slider) {
                $url = $slider->image;
                $relativePath = parse_url($url, PHP_URL_PATH);
                if (Storage::disk(config('filesystems.default'))->exists($relativePath)) {
                    Storage::disk(config('filesystems.default'))->delete($relativePath);
                }
                $slider->delete();
                ResponseService::successResponse('slider delete successfully');
            }

        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "Slider Controller -> destroy");
            ResponseService::errorResponse('something is wrong !!!');
        }
    }

    public function show(Request $request) {
        ResponseService::noPermissionThenRedirect('slider-list');
        $offset = $request->offset ?? 0;
        $limit = $request->limit ?? 10;
        $sort = $request->sort ?? 'id';
        $order = $request->order ?? 'DESC';
        $sql = Slider::with('model')->sort($sort, $order);
        if (!empty($request->search)) {
            $sql = $sql->search($request->search);
        }



        $startDate = $this->safeParseDate($request->input('start_date'));
        $endDate = $this->safeParseDate($request->input('end_date'), true);


        if ($request->filled('status')) {
            $sql = $sql->status(Str::of($request->status)->explode(',')->filter()->toArray() ?: $request->status);
        }



        $interfaceTypeFilter = null;
        $interfaceTypeVariants = [];

        if ($request->filled('interface_type')) {
            if ($request->interface_type === 'all') {
                $interfaceTypeFilter = 'all';
            } else {
                $interfaceTypeFilter = InterfaceSectionService::normalizeSectionType($request->interface_type);
                $interfaceTypeVariants = InterfaceSectionService::sectionTypeVariants($interfaceTypeFilter);
            }
        }

        if ($interfaceTypeFilter !== null && $interfaceTypeFilter !== 'all') {
            $sql = $sql->whereIn('interface_type', $interfaceTypeVariants);


        }
        $total = $sql->count();
        $sql->skip($offset)->take($limit);
        $result = $sql->get();
        $metrics = $this->sliderMetricService->summarizeForSliders($result->pluck('id'), $startDate, $endDate);

        $rows = [];

        foreach ($result as $row) {


            $tempRow = $row->toArray();
            $operate = '';
            if (Auth::user()->can('slider-delete')) {
                $operate .= BootstrapTableService::deleteButton(route('slider.destroy', $row->id));
            }
            $summary = $metrics->get($row->id, ['impressions' => 0, 'clicks' => 0, 'ctr' => 0.0]);


            $tempRow['operate'] = $operate;

            $tempRow['impressions'] = (int) ($summary['impressions'] ?? 0);
            $tempRow['clicks'] = (int) ($summary['clicks'] ?? 0);
            $tempRow['ctr'] = (float) ($summary['ctr'] ?? 0.0);
            $tempRow['per_user_per_day_limit'] = $row->per_user_per_day_limit;
            $tempRow['per_user_per_session_limit'] = $row->per_user_per_session_limit;

            $rows[] = $tempRow;
        }

        $bulkData['rows'] = $rows;
        return response()->json($bulkData);


        return response()->json([
            'total' => $total,
            'rows'  => $rows,
        ]);
    }

    public function metricsSummary(Request $request)
    {
        ResponseService::noPermissionThenRedirect('slider-list');

        $startDate = $this->safeParseDate($request->input('start_date'));
        $endDate = $this->safeParseDate($request->input('end_date'), true);

        $daily = $this->sliderMetricService->getDailyAggregates($startDate, $endDate)->values()->all();
        $weekly = $this->sliderMetricService->getWeeklyAggregates($startDate, $endDate)->values()->all();
        $statusMetricsRaw = $this->sliderMetricService->getStatusAggregates($startDate, $endDate);
        $interfaceMetricsRaw = $this->sliderMetricService->getInterfaceTypeAggregates($startDate, $endDate);

        return response()->json([
            'daily'      => $daily,
            'weekly'     => $weekly,
            'status'     => $this->buildStatusMetrics($statusMetricsRaw)->all(),
            'interface'  => $this->buildInterfaceMetrics($interfaceMetricsRaw)->all(),
        ]);
    }

    protected function safeParseDate(?string $value, bool $endOfDay = false): ?Carbon
    {
        if (! is_string($value) || trim($value) === '') {
            return null;
        }

        try {
            $date = Carbon::parse($value);
        } catch (\Throwable) {
            return null;
        }

        return $endOfDay ? $date->endOfDay() : $date->startOfDay();
    }

    protected function buildStatusMetrics(Collection $statusMetricsRaw): Collection
    {
        $availableStatuses = Slider::availableStatuses();

        $statusMetricMap = $statusMetricsRaw
            ->mapWithKeys(fn (array $row) => [($row['status'] ?? '') => $row]);

        $statusMetrics = collect($availableStatuses)
            ->map(function (string $status) use ($statusMetricMap) {
                $row = $statusMetricMap->get($status, []);

                return [
                    'status'      => $status,
                    'impressions' => (int) ($row['impressions'] ?? 0),
                    'clicks'      => (int) ($row['clicks'] ?? 0),
                    'ctr'         => (float) ($row['ctr'] ?? 0.0),
                ];
            });

        $extraStatusMetrics = $statusMetricsRaw->filter(function (array $row) use ($availableStatuses) {
            $status = $row['status'] ?? null;

            return $status && ! in_array($status, $availableStatuses, true);
        });

        if ($extraStatusMetrics->isNotEmpty()) {
            $statusMetrics = $statusMetrics->merge($extraStatusMetrics->values());
        }

        return $statusMetrics->values();
    }

    protected function buildInterfaceMetrics(Collection $interfaceMetricsRaw): Collection
    {
        return $interfaceMetricsRaw
            ->map(function (array $row) {
                $interfaceType = $row['interface_type'] ?? 'all';

                return [
                    'interface_type' => $interfaceType,
                    'impressions'    => (int) ($row['impressions'] ?? 0),
                    'clicks'         => (int) ($row['clicks'] ?? 0),
                    'ctr'            => (float) ($row['ctr'] ?? 0.0),
                ];
            })
            ->values();

    }
}

