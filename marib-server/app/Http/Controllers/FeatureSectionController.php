<?php

namespace App\Http\Controllers;

use App\Models\FeatureSection;
use App\Services\BootstrapTableService;
use App\Models\Item;
use App\Services\FeaturedSectionService;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use App\Services\ResponseService;
use Illuminate\Http\Request;
use App\Services\FeatureSectionCategoryService;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;
use Illuminate\Support\Facades\Schema;
use Illuminate\Http\JsonResponse;

use Throwable;

class FeatureSectionController extends Controller {



    public function index() {
        ResponseService::noAnyPermissionThenRedirect(['feature-section-list', 'feature-section-create', 'feature-section-update', 'feature-section-delete']);
        $allowedSectionTypes = FeatureSectionCategoryService::allowedSectionTypes();
        $defaultSectionType = FeatureSectionCategoryService::defaultSectionType() ?? ($allowedSectionTypes[0] ?? null);
        


        $usedFilterSlugMap = $this->usedFilterSlugsBySectionType();


        return view('feature_section.index', [
            'allowedSectionTypes' => $allowedSectionTypes,
            'defaultSectionType'  => $defaultSectionType,

            'filterDefinitions'    => FeatureSection::filterDefinitions(),
            'filterLabels'         => FeatureSection::filterLabels(),
            'filterSlugOptions'    => $this->filterSlugOptions(),
            'filterCanonicalSlugs' => $this->filterCanonicalSlugs(),
            'usedFilterSlugMap'    => $usedFilterSlugMap,
            'rootIdentifiers'      => FeatureSectionCategoryService::rootIdentifiers(),
            'previewRoute'         => route('feature-section.preview'),
            'probeRoute'           => route('feature-section.probe'),
            'flushCacheRoute'      => route('feature-section.flush-cache'),
            'slugUnavailableMessage' => __('All slug variants for this filter are already assigned. Please edit the existing feature section instead of creating a duplicate.'),


        ]);


    }


    public function categories(Request $request)
    {
        ResponseService::noAnyPermissionThenSendJson(['feature-section-create', 'feature-section-update']);

        try {
            $allowedSectionTypes = FeatureSectionCategoryService::allowedSectionTypes();
            $defaultSectionType = FeatureSectionCategoryService::defaultSectionType() ?? ($allowedSectionTypes[0] ?? null);
            $requestedSectionType = $request->input('section_type');
            $sectionType = $request->filled('section_type')
                ? FeatureSectionCategoryService::normalizeSectionType($requestedSectionType)
                : $defaultSectionType;

            if (! in_array($sectionType, $allowedSectionTypes, true)) {
                $sectionType = $defaultSectionType;
            }

            
            
            $categories = FeatureSectionCategoryService::categoriesForSection($sectionType);

            $options = view('category.dropdowntree', [
                'categories' => $categories,
            ])->render();

            return response()->json([
                'options' => $options,
            ]);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'FeaturedSection Controller -> categories');
            ResponseService::errorResponse();
        }
    }


    public function store(Request $request) {
        ResponseService::noPermissionThenSendJson('feature-section-create');
        $allowedSectionTypes = FeatureSectionCategoryService::allowedSectionTypes();
        $validationSectionTypes = FeatureSectionCategoryService::allowedSectionTypes(includeLegacy: true);

        $defaultSectionType = FeatureSectionCategoryService::defaultSectionType() ?? ($allowedSectionTypes[0] ?? null);
        $normalizedSectionType = $this->transformSectionTypeInput($request, $defaultSectionType);

        if ($request->has('filter_type')) {
            $request->merge(['filter' => $request->input('filter_type')]);
        }

        $this->ensureTitleFromFilter($request);


        $normalizedInputSlug = FeatureSection::normalizeSlug($request->input('slug'));

        $expectedSlug = $this->resolveSlugFromRequest($request);


        $request->merge([
            'slug' => $expectedSlug,
        ]);

        $resolvedSectionType = $normalizedSectionType ?: $defaultSectionType;

        if ($normalizedInputSlug === '' && $this->isSlugPoolExhausted($request->input('filter'), $resolvedSectionType)) {
            ResponseService::validationError(__('All slug variants for this filter are already assigned. Please edit the existing feature section instead of creating a duplicate.'));
        }


        $messages = [
            'slug.regex'        => 'Slug may only include lowercase letters, numbers, and underscores.',


            'section_type.regex' => 'Section type may only include lowercase letters, numbers, and underscores.',
            'section_type.in'    => 'Please choose one of the available section types.',
            'slug.unique'        => 'This slug is already used for the selected section type.',
        ];


        $validator = Validator::make($request->all(), [
            'title'       => 'required',
            'slug'        => [
                'required',
                'string',
                
                'regex:/^[a-z0-9_]+$/',



                Rule::unique('feature_sections')->where(
                    static fn($q) => $q->where('section_type', $normalizedSectionType)
                ),


                function (string $attribute, mixed $value, \Closure $fail) use ($request): void {
                    $filter = $request->input('filter');

                    if (! FeatureSection::slugMatchesFilter((string) $value, $filter)) {
                        $allowed = FeatureSection::allowedSlugsForFilter($filter);
                        $expected = $allowed === []
                            ? ($filter ? FeatureSection::normalizeSlug($filter) : __('the selected filter'))
                            : implode(', ', $allowed);

                        $fail(__('The :attribute must match the selected filter (:expected).', [
                            'attribute' => $attribute,
                            'expected'  => $expected,
                        ]));
                    }
                },

            ],
            
            'filter'      => ['required', Rule::in(FeatureSection::supportedFilters())],
            'style'       => 'required|in:style_1,style_2,style_3,style_4',

            'description' => 'nullable|string',
            'is_active'   => ['sometimes', 'boolean'],
            'section_type' => ['nullable', 'string', 'regex:/^[a-z0-9_]+$/', Rule::in($validationSectionTypes)],


        ], $messages, [
            'section_type' => 'section type',
                ]);


        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }

        try {
            $data = [
                ...$request->all(),
                'sequence' => FeatureSection::max('sequence') + 1,
            ];


            $data['section_type'] = $request->input('section_type', $defaultSectionType);
            $data['slug'] = $expectedSlug;

            $data['min_price'] = null;
            $data['max_price'] = null;


            $data['value'] = null;

            $data['is_active'] = $request->boolean('is_active', true);



            FeatureSection::create($data);
            ResponseService::successResponse('Feature Section Added Successfully');
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "FeaturedSection Controller -> store");
            ResponseService::errorResponse();
        }

    }

    public function list(Request $request): JsonResponse
    {
        ResponseService::noPermissionThenSendJson('feature-section-list');

        return response()->json($this->prepareListResponse($request));
    }


    public function show(FeatureSection $featureSection): JsonResponse

    {
        
        
        ResponseService::noPermissionThenSendJson('feature-section-list');

        $section = $featureSection->load('category');

        return response()->json($this->transformSectionResponse($section));

    }


    private function prepareListResponse(Request $request): array
    {

        $offset = max(0, (int) $request->input('offset', 0));
        $limit = (int) $request->input('limit', 10);
        $limit = max(1, min(200, $limit));
        
        $sort = $request->input('sort', 'sequence');
        $order = strtoupper((string) $request->input('order', 'ASC')) === 'DESC' ? 'DESC' : 'ASC';


        if (! Schema::hasColumn('feature_sections', $sort)) {
            $sort = 'sequence';
        }

        $query = $this->buildListQuery($request);
        $total = (clone $query)->count();


        $sections = $query
            ->orderBy($sort, $order)
            ->skip($offset)
            ->take($limit)
            ->get();



        $includeActionsInput = $request->input('include_actions');
        $includeActions = true;

        if ($includeActionsInput !== null) {
            $parsedIncludeActions = filter_var($includeActionsInput, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
            if ($parsedIncludeActions !== null) {
                $includeActions = $parsedIncludeActions;
            }
        }

        $rows = [];

        foreach ($sections as $section) {
            $rows[] = $this->transformSectionResponse($section, includeActions: $includeActions);


        }
        return [
            'total' => $total,
            'rows'  => $rows,
        ];
    }


    private function buildListQuery(Request $request): Builder
    {
        $query = FeatureSection::query()->with('category');

        $search = trim((string) $request->input('search', ''));

        if ($search !== '') {
            $query->search($search);
        }


        $allowedSectionTypes = FeatureSectionCategoryService::allowedSectionTypes(includeLegacy: true);
        $sectionType = $request->input('section_type');

        if ($sectionType !== null && $sectionType !== '') {
            $normalizedSectionType = FeatureSectionCategoryService::normalizeSectionType((string) $sectionType);

            if (in_array($normalizedSectionType, $allowedSectionTypes, true)) {
                $query->where('section_type', $normalizedSectionType);
            }
        }

        if ($request->has('is_active')) {
            $isActive = filter_var($request->input('is_active'), FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);

            if ($isActive !== null) {
                $query->where('is_active', $isActive);
            }
        }

        return $query;
    }




    public function update(Request $request, $id) {
        ResponseService::noPermissionThenSendJson('feature-section-update');
        $allowedSectionTypes = FeatureSectionCategoryService::allowedSectionTypes();
        $validationSectionTypes = FeatureSectionCategoryService::allowedSectionTypes(includeLegacy: true);




        try {
            $feature_section = FeatureSection::findOrFail($id);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'FeaturedSection Controller -> update');
            ResponseService::errorResponse();

            return;
        }

        $fallbackSectionType = $feature_section->section_type ?? FeatureSectionCategoryService::defaultSectionType();
            $normalizedSectionType = $this->transformSectionTypeInput($request, $fallbackSectionType);

        if ($request->has('filter_type')) {
            $request->merge(['filter' => $request->input('filter_type')]);
        }

        $this->ensureTitleFromFilter($request);

        $normalizedInputSlug = FeatureSection::normalizeSlug($request->input('slug'));

        $expectedSlug = $this->resolveSlugFromRequest($request);


        $request->merge([
            'slug' => $expectedSlug,
        ]);


        $resolvedSectionType = $normalizedSectionType ?: $fallbackSectionType;
        $currentSlugNormalized = FeatureSection::normalizeSlug($feature_section->slug);

        if ($currentSlugNormalized === '') {
            $currentSlugNormalized = null;
        }

        if ($normalizedInputSlug === '' && $this->isSlugPoolExhausted($request->input('filter'), $resolvedSectionType, $feature_section->id, $currentSlugNormalized)) {
            ResponseService::validationError(__('All slug variants for this filter are already assigned. Please edit the existing feature section instead of creating a duplicate.'));
        }

        $messages = [
            
            'slug.regex'        => 'Slug may only include lowercase letters, numbers, and underscores.',


            'section_type.regex' => 'Section type may only include lowercase letters, numbers, and underscores.',
            'section_type.in'    => 'Please choose one of the available section types.',
            'slug.unique'        => 'This slug is already used for the selected section type.',
        ];




        $validator = Validator::make($request->all(), [
            'title'       => 'required',
            'description' => 'nullable|string',
            'is_active'   => ['nullable', 'boolean'],


            'slug'        => [
                'required',
                'string',
                'regex:/^[a-z0-9_]+$/',


                Rule::unique('feature_sections')
                    ->where(static fn($q) => $q->where('section_type', $normalizedSectionType))
                    ->ignore($feature_section->id),
                function (string $attribute, mixed $value, \Closure $fail) use ($request): void {
                    $filter = $request->input('filter');

                    if (! FeatureSection::slugMatchesFilter((string) $value, $filter)) {
                        $allowed = FeatureSection::allowedSlugsForFilter($filter);
                        $expected = $allowed === []
                            ? ($filter ? FeatureSection::normalizeSlug($filter) : __('the selected filter'))
                            : implode(', ', $allowed);

                        $fail(__('The :attribute must match the selected filter (:expected).', [
                            'attribute' => $attribute,
                            'expected'  => $expected,
                        ]));
                    }
                },

            ],


            'filter'      => ['required', Rule::in(FeatureSection::supportedFilters())],

            'style'       => 'required|in:style_1,style_2,style_3,style_4',

            'section_type' => ['nullable', 'string', 'regex:/^[a-z0-9_]+$/', Rule::in($validationSectionTypes)],



            
        ], $messages, [
            'section_type' => 'section type',
        
        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }
        try {

            $data = $request->all();


            $data['section_type'] = $request->input('section_type', $fallbackSectionType);
            $data['slug'] = $expectedSlug;

            $data['min_price'] = null;
            $data['max_price'] = null;

            $data['value'] = null;
            $data['is_active'] = $request->has('is_active')
                ? filter_var($request->input('is_active'), FILTER_VALIDATE_BOOLEAN)
                : (bool) $feature_section->is_active;
            $data['is_active'] = $request->boolean('is_active', (bool) $feature_section->is_active);
            



            $feature_section->update($data);
            ResponseService::successResponse('Feature Section Updated Successfully');
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "FeaturedSection Controller -> update");
            ResponseService::errorResponse();
        }
    }




    public function preview(Request $request, FeaturedSectionService $featuredSectionService)
    {
        ResponseService::noAnyPermissionThenSendJson(['feature-section-create', 'feature-section-update']);

        $allowedSectionTypes = FeatureSectionCategoryService::allowedSectionTypes();
        $validationSectionTypes = FeatureSectionCategoryService::allowedSectionTypes(includeLegacy: true);
        $defaultSectionType = FeatureSectionCategoryService::defaultSectionType() ?? ($allowedSectionTypes[0] ?? null);
        $normalizedSectionType = $this->transformSectionTypeInput($request, $defaultSectionType);

        if ($request->has('filter_type')) {
            $request->merge(['filter' => $request->input('filter_type')]);
        }

        $expectedSlug = $this->resolveSlugFromRequest($request);
        $request->merge([
            'slug' => $expectedSlug,
        ]);

        $messages = [
            'slug.regex'         => 'Slug may only include lowercase letters, numbers, and underscores.',
            'section_type.regex' => 'Section type may only include lowercase letters, numbers, and underscores.',
            'section_type.in'    => 'Please choose one of the available section types.',
        ];

        $validator = Validator::make($request->all(), [
            'slug'          => ['required', 'string', 'regex:/^[a-z0-9_]+$/'],
            'filter'        => ['required', Rule::in(FeatureSection::supportedFilters())],
            'section_type'  => ['nullable', 'string', 'regex:/^[a-z0-9_]+$/', Rule::in($validationSectionTypes)],
            'limit'         => ['nullable', 'integer', 'min:1', 'max:100'],
        ], $messages, [
            'section_type' => 'section type',
        ]);


        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }

        try {
            $filter = $request->input('filter');
            $sectionType = $normalizedSectionType;
            $slug = FeatureSection::normalizeSlug($request->input('slug'));

            if (! FeatureSection::slugMatchesFilter($slug, $filter)) {
                $allowed = FeatureSection::allowedSlugsForFilter($filter);
                $expected = $allowed === []
                    ? ($filter ? FeatureSection::normalizeSlug($filter) : __('the selected filter'))
                    : implode(', ', $allowed);

                ResponseService::validationError(__('The slug must match the selected filter (:expected).', [
                    'expected' => $expected,
                ]));
            }



            $section = new FeatureSection([
                'title'        => $request->input('title', ''),
                'slug'         => $slug,
                'filter'       => $filter,
                'section_type' => $sectionType,
                'value'        => $request->input('value'),
                'style'        => $request->input('style', 'style_1'),
                'description'  => $request->input('description'),
                'is_active'    => true,
            ]);

            $limit = $request->filled('limit') ? (int) $request->input('limit') : $this->resolveSectionLimit($section);
            if ($limit <= 0) {
                $limit = 5;
            }


            $previewResult = $featuredSectionService->previewSection($section, [
                'limit'         => $limit,

            ]);

            $sectionPayload = $previewResult->section;
            $totalData = (int) ($sectionPayload['total_data'] ?? 0);
            $warning = $totalData === 0;

            return response()->json([
                'success'     => true,
                'section'     => $sectionPayload,
                'etag'        => $previewResult->etag,
                'total_data'  => $totalData,
                'warning'     => $warning,
                'limit'       => $limit,
            ]);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'FeaturedSection Controller -> preview', jsonResponse: false);

            return response()->json([
                'success' => false,
                'message' => __('Error Occurred'),
            ], 500);
        }
    }

    public function probe(Request $request)
    {
        ResponseService::noAnyPermissionThenSendJson(['feature-section-create', 'feature-section-update']);

        $allowedSectionTypes = FeatureSectionCategoryService::allowedSectionTypes(includeLegacy: true);
        $messages = [
            'section_type.regex' => 'Section type may only include lowercase letters, numbers, and underscores.',
            'section_type.in'    => 'Please choose one of the available section types.',
        ];

        $validator = Validator::make($request->all(), [
            'slug'          => ['required', 'string', 'regex:/^[a-z0-9_]+$/'],
            'section_type'  => ['nullable', 'string', 'regex:/^[a-z0-9_]+$/', Rule::in($allowedSectionTypes)],
            'limit'         => ['nullable', 'integer', 'min:1', 'max:100'],

            'interface_type' => ['nullable', 'string'],
        ], $messages, [
            'section_type' => 'section type',
        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }

        try {
            $normalizedSectionType = FeatureSectionCategoryService::normalizeSectionType($request->input('section_type'));
            $normalizedSlug = FeatureSection::normalizeSlug($request->input('slug'));

            if ($normalizedSlug === '') {
                ResponseService::validationError(__('Slug may not be empty.'));
            }

            $query = array_filter([
                'section_type'   => $normalizedSectionType,
                'slug'           => $normalizedSlug,
                'limit'          => $request->input('limit'),

                'interface_type' => $request->input('interface_type'),
            ], static function ($value) {
                return $value !== null && $value !== '';
            });

            $apiUrl = url('/api/get-featured-section');
            $httpResponse = Http::acceptJson()->get($apiUrl, $query);

            return response()->json([
                'success' => $httpResponse->successful(),
                'status'  => $httpResponse->status(),
                'payload' => $httpResponse->json(),
            ]);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'FeaturedSection Controller -> probe', jsonResponse: false);

            return response()->json([
                'success' => false,
                'message' => __('Error Occurred'),
            ], 500);
        }
    }

    public function flushCache(Request $request)
    {
        ResponseService::noAnyPermissionThenSendJson(['feature-section-create', 'feature-section-update']);

        $allowedSectionTypes = FeatureSectionCategoryService::allowedSectionTypes(includeLegacy: true);

        $validator = Validator::make($request->all(), [
            'slug'         => ['required', 'string', 'regex:/^[a-z0-9_]+$/'],
            'section_type' => ['required', 'string', 'regex:/^[a-z0-9_]+$/', Rule::in($allowedSectionTypes)],
        ], [
            'section_type.regex' => 'Section type may only include lowercase letters, numbers, and underscores.',
            'section_type.in'    => 'Please choose one of the available section types.',
        ], [
            'section_type' => 'section type',
        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }

        try {
            $normalizedSectionType = FeatureSectionCategoryService::normalizeSectionType($request->input('section_type'));
            $normalizedSlug = FeatureSection::normalizeSlug($request->input('slug'));

            if ($normalizedSlug === '') {
                ResponseService::validationError(__('Slug may not be empty.'));
            }

            $variants = FeatureSectionCategoryService::sectionTypeVariants($normalizedSectionType);
            if (! in_array($normalizedSectionType, $variants, true)) {
                $variants[] = $normalizedSectionType;
            }

            $variants = array_values(array_unique($variants));

            $flushedKeys = [];

            foreach ($variants as $variant) {
                $cacheKey = sprintf('featured-section:%s:%s', $variant, $normalizedSlug);

                Cache::forget($cacheKey);
                $flushedKeys[] = $cacheKey;
            }

            return response()->json([
                'success' => true,
                'flushed' => $flushedKeys,
            ]);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'FeaturedSection Controller -> flushCache', jsonResponse: false);

            return response()->json([
                'success' => false,
                'message' => __('Error Occurred'),
            ], 500);
        }
    }





    public function destroy($id) {
        try {
            ResponseService::noPermissionThenSendJson('feature-section-delete');
            FeatureSection::findOrFail($id)->delete();
            ResponseService::successResponse('Feature Section delete successfully');
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "FeaturedSection Controller -> destroy");
            ResponseService::errorResponse('Something Went Wrong');
        }
    }


    private function resolveSlugFromRequest(Request $request): string
    {
        $filter = $request->input('filter');


        if (! is_string($request->input('slug')) && $request->has('slug') && $request->input('slug') !== null) {
            ResponseService::validationError(__('The slug must be a string.'));
        }

        $providedSlug = FeatureSection::normalizeSlug($request->input('slug'));

        if ($providedSlug !== '') {
            // Allow the validation pipeline to handle mismatched slugs so the user receives
            // a detailed error that includes the expected aliases for the chosen filter.
            return $providedSlug;
        }

        $expectedSlug = FeatureSection::canonicalSlugForFilter($filter);

        if ($expectedSlug === null || $expectedSlug === '') {
            $expectedSlug = FeatureSection::normalizeSlug($filter);
        }

        if ($expectedSlug === '') {
            if (! is_string($filter) || trim($filter) === '') {
                return '';
            }

            ResponseService::validationError(__('Unable to determine a slug for the selected filter.'));
        }

        return $expectedSlug;
    }


    private function ensureTitleFromFilter(Request $request): void
    {
        $rawTitle = $request->input('title');

        if (is_string($rawTitle) && trim($rawTitle) !== '') {
            return;
        }

        $filter = $request->input('filter');

        if (! is_string($filter) || trim($filter) === '') {
            return;
        }

        $labels = FeatureSection::filterLabels();
        $label = $labels[$filter] ?? null;

        $resolved = is_string($label) && trim($label) !== ''
            ? trim((string) $label)
            : trim($filter);

        if ($resolved === '') {
            return;
        }

        $request->merge(['title' => $resolved]);
    }


    
    private function transformSectionResponse(FeatureSection $section, bool $includeActions = false): array
    {
        $data = $section->toArray();

        $data['section_type'] = FeatureSectionCategoryService::normalizeSectionType($section->section_type);
        $data['total_data'] = $this->calculateSectionTotalData($section);
        $data['is_active'] = (bool) $section->is_active;
        $data['status_update_url'] = route('feature-section.status', $section->id);


        if ($includeActions) {
            $operate = '';
            $user = Auth::user();

            if ($user && $user->can('feature-section-update')) {
                $operate .= BootstrapTableService::editButton(route('feature-section.update', $section->id), true);
            }

            if ($user && $user->can('feature-section-delete')) {
                $operate .= BootstrapTableService::deleteButton(route('feature-section.destroy', $section->id));
            }

            $data['operate'] = $operate;
        }

        return $data;
    }




    public function updateStatus(Request $request, FeatureSection $featureSection): JsonResponse
    {
        ResponseService::noPermissionThenSendJson('feature-section-update');

        $validator = Validator::make($request->all(), [
            'is_active' => ['required', 'boolean'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => $validator->errors()->first(),
            ], 422);
        }

        try {
            $featureSection->is_active = $request->boolean('is_active');
            $featureSection->save();

            $featureSection->refresh();

            return response()->json([
                'success' => true,
                'message' => __('Feature section status updated successfully.'),
                'data' => $this->transformSectionResponse($featureSection, includeActions: true),
            ]);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'FeaturedSection Controller -> updateStatus');

            return response()->json([
                'success' => false,
                'message' => __('Unable to update feature section status. Please try again.'),
            ], 500);
        }
    }





    private function calculateSectionTotalData(FeatureSection $section): int
    {
        try {
            $canonicalSectionType = FeatureSectionCategoryService::normalizeSectionType($section->section_type);
            $allowedSectionTypes = FeatureSectionCategoryService::allowedSectionTypes(includeLegacy: true);
            $canonicalSectionTypes = FeatureSectionCategoryService::allowedSectionTypes();

            $itemsQuery = Item::query()
                ->select('items.id')
                ->has('user')
                ->approved()
                ->getNonExpiredItems();

            $categoryFilterIds = FeatureSectionCategoryService::categoryIdsForSection($canonicalSectionType);

            if (is_array($categoryFilterIds)) {
                if ($categoryFilterIds === []) {
                    return 0;
                }

                $itemsQuery->whereIn('category_id', $categoryFilterIds);
            }

            if (
                $canonicalSectionType !== null
                && $canonicalSectionType !== 'all'
                && in_array($canonicalSectionType, $canonicalSectionTypes, true)
            ) {
                $variants = FeatureSectionCategoryService::sectionTypeVariants($canonicalSectionType);

                if ($variants !== []) {
                    $itemsQuery->whereIn('interface_type', $variants);
                }
            } else {
                $expanded = FeatureSectionCategoryService::expandSectionTypes($allowedSectionTypes);

                if ($expanded !== []) {
                    $itemsQuery->whereIn('interface_type', $expanded);
                }
            }

            $filter = $section->filter;
            $supportedFilters = FeatureSection::supportedFilters();

            if (! in_array($filter, $supportedFilters, true)) {
                $filter = 'latest';
            }



            $limit = $this->resolveSectionLimit($section);

            return $itemsQuery->limit($limit)->get()->count();
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'FeaturedSection Controller -> calculateSectionTotalData');

            return 0;
        }
    }

    private function resolveSectionLimit(FeatureSection $section): int
    {
        $defaultLimit = 5;
        $rawValue = $section->value;

        if (is_numeric($rawValue)) {
            $limit = (int) $rawValue;

            return $limit > 0 ? $limit : $defaultLimit;
        }

        if (is_array($rawValue)) {
            $candidate = $rawValue['limit'] ?? null;

            if (is_numeric($candidate)) {
                $limit = (int) $candidate;

                return $limit > 0 ? $limit : $defaultLimit;
            }
        }

        if (is_string($rawValue)) {
            $decoded = json_decode($rawValue, true);

            if (json_last_error() === JSON_ERROR_NONE && is_array($decoded)) {
                $candidate = $decoded['limit'] ?? null;

                if (is_numeric($candidate)) {
                    $limit = (int) $candidate;

                    return $limit > 0 ? $limit : $defaultLimit;
                }
            }
        }

        return $defaultLimit;
    }


    private function transformSectionTypeInput(Request $request, ?string $fallback = null): ?string
    {
        if ($request->exists('section_type')) {
            $raw = $request->input('section_type');

            if (! is_string($raw)) {
                return null;
            }

            $trimmed = trim($raw);

            if ($trimmed === '') {
                $request->merge(['section_type' => '']);

                return null;
            }

            $normalized = FeatureSectionCategoryService::normalizeSectionType($trimmed);
            $request->merge(['section_type' => $normalized]);

            return $normalized;
        }

        if ($fallback !== null) {
            $normalized = FeatureSectionCategoryService::normalizeSectionType($fallback);
            $request->merge(['section_type' => $normalized]);

            return $normalized;
        }

        return null;
    }


    private function filterSlugOptions(): array
    {
        $options = [];

        foreach (FeatureSection::supportedFilters() as $filter) {
            $options[$filter] = FeatureSection::allowedSlugsForFilter($filter);
        }

        return $options;
    }

    private function filterCanonicalSlugs(): array
    {
        $canonical = [];

        foreach (FeatureSection::supportedFilters() as $filter) {
            $canonical[$filter] = FeatureSection::canonicalSlugForFilter($filter);
        }

        return $canonical;
    }




    private function isSlugPoolExhausted(?string $filter, ?string $sectionType, ?int $ignoreId = null, ?string $currentSlug = null): bool
    {
        $allowedSlugs = FeatureSection::allowedSlugsForFilter($filter);

        if ($allowedSlugs === []) {
            return false;
        }

        if ($sectionType === null || $sectionType === '') {
            return false;
        }

        $normalizedSectionType = FeatureSectionCategoryService::normalizeSectionType($sectionType);

        $usedQuery = FeatureSection::query()
            ->where('section_type', $normalizedSectionType);

        if ($ignoreId !== null) {
            $usedQuery->where('id', '!=', $ignoreId);
        }

        $usedSlugs = $usedQuery
            ->pluck('slug')
            ->map(static fn($slug) => FeatureSection::normalizeSlug($slug))
            ->filter()
            ->unique()
            ->all();

        $usedLookup = array_fill_keys($usedSlugs, true);

        $normalizedCurrent = FeatureSection::normalizeSlug($currentSlug);

        if ($normalizedCurrent === '') {
            $normalizedCurrent = null;
        }

        foreach ($allowedSlugs as $slug) {
            if ($slug === '') {
                continue;
            }

            if ($normalizedCurrent !== null && $slug === $normalizedCurrent) {
                return false;
            }

            if (! isset($usedLookup[$slug])) {
                return false;
            }
        }

        return true;
    }



    

    private function usedFilterSlugsBySectionType(): array
    {
        $labels = FeatureSection::filterLabels();

        $sections = FeatureSection::query()
            ->select(['section_type', 'filter', 'slug', 'title'])
            ->get()
            ->groupBy(static function (FeatureSection $section): string {
                return FeatureSectionCategoryService::normalizeSectionType($section->section_type);
            });

        $result = [];

        foreach ($sections as $sectionType => $items) {
            foreach ($items as $section) {
                $filter = $section->filter;

                if (! is_string($filter) || $filter === '') {
                    continue;
                }

                $normalizedSlug = FeatureSection::normalizeSlug($section->slug);

                if ($normalizedSlug === '') {
                    
                    continue;
                }

                if (! FeatureSection::slugMatchesFilter($normalizedSlug, $filter)) {

                    continue;
                }

                $canonical = FeatureSection::canonicalSlugForFilter($filter);

                $result[$sectionType][$normalizedSlug] = [
                    'filter'         => $filter,
                    'filter_label'   => $labels[$filter] ?? $filter,
                    'slug'           => $normalizedSlug,
                    'canonical_slug' => $canonical,
                    'title'          => $section->title,
                ];
            }
        }

        ksort($result);

        foreach ($result as $sectionType => $map) {
            ksort($map);
            $result[$sectionType] = $map;
        }

        return $result;
    }


}
