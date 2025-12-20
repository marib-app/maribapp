<?php

namespace App\Http\Controllers;
use App\Models\FeaturedItems;

use App\Models\Item;
use App\Models\ItemCustomFieldValue;
use App\Models\UserFcmToken;
use App\Services\BootstrapTableService;
use App\Services\DepartmentAdvertiserService;
use App\Services\DepartmentReportService;
use App\Services\FileService;
use App\Services\InterfaceSectionService;
use App\Policies\SectionDelegatePolicy;
use App\Services\ImageVariantService;

use App\Services\NotificationService;
use App\Services\ResponseService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Storage;
use App\Support\ColorFieldParser;
use Illuminate\Support\Facades\Gate;

use App\Models\Category;
use App\Models\CustomField;
use Throwable;
use Illuminate\Validation\ValidationException;
use Illuminate\Support\Facades\Log;
use Carbon\Carbon;

use Illuminate\Support\Collection;

class ItemController extends Controller {


    public function __construct(private readonly DepartmentAdvertiserService $departmentAdvertiserService)
    {
    }

    public function index() {
        ResponseService::noAnyPermissionThenRedirect(['item-list', 'item-update', 'item-delete']);
        $allowedCategories = [2,8, 174, 175, 176, 181, 180, 177];
        $categories = Category::whereNotIn('id', $allowedCategories)->get();
        return view('items.index', compact('categories'));
    
    }

    

  public function create(Request $request)
    {
        ResponseService::noAnyPermissionThenRedirect(['shein-products-create', 'computer-ads-create']);

        $section = strtolower((string) $request->input('section', ''));
        $categoryRoot = $request->input('category_root');

        $sectionRedirects = [
            'shein' => 'item.shein.products.create',
            'computer' => 'item.computer.create',
        ];

        $categoryRedirects = [
            4 => 'shein',
            5 => 'computer',
        ];

        if ($section !== '' && isset($sectionRedirects[$section])) {
            return redirect()->route($sectionRedirects[$section]);
        }

        if ($categoryRoot !== null && is_numeric($categoryRoot)) {
            $categoryRoot = (int) $categoryRoot;

            if (isset($categoryRedirects[$categoryRoot])) {
                $targetSection = $categoryRedirects[$categoryRoot];

                return redirect()->route($sectionRedirects[$targetSection]);
            }
        }

        if (Auth::user()?->can('shein-products-create')) {
            return redirect()->route('item.shein.products.create');
        }

        if (Auth::user()?->can('computer-ads-create')) {
            return redirect()->route('item.computer.create');
        }

        abort(404);
    }




    public function shein()

    {
        ResponseService::noAnyPermissionThenRedirect([
            'shein-products-list', 'shein-products-create', 'shein-products-update', 'shein-products-delete',
            'shein-orders-list', 'shein-orders-create', 'shein-orders-update', 'shein-orders-delete'
        ]);

        $advertiser = $this->departmentAdvertiserService->getAdvertiser(DepartmentReportService::DEPARTMENT_SHEIN);

        return view('items.shein.index', compact('advertiser'));
    
    }

    public function sheinProducts()
    {

        ResponseService::noAnyPermissionThenRedirect(['shein-products-list', 'shein-products-update', 'shein-products-delete']);
     
        $categoryPool = $this->getCategoryPool();
        $categoryIds = $this->collectSectionCategoryIds($categoryPool, 4, true);

        $categories = $categoryPool
            ->filter(static fn ($category) => in_array($category->id, $categoryIds, true))
            ->sortBy(static function ($category) {
                $sequence = $category->sequence ?? 999999;

                return sprintf('%06d-%s', $sequence, $category->name);
            })
            ->values();




        return view('items.shein', compact('categories'));
    }



    public function sheinProductsData(Request $request)
    {
        if (! $request->filled('section')) {
            $request->merge([
                'section' => DepartmentReportService::DEPARTMENT_SHEIN,
            ]);
        }

        if (! $request->has('category_root') || ! is_numeric($request->input('category_root'))) {
            $request->merge([
                'category_root' => 4,
            ]);
        }

        if (! $request->filled('category_id') && (int) $request->input('category_root') === 4) {
            $request->merge([
                'category_id' => 4,
            ]);
        }

        return $this->show($request);
    }


    /**
     * Show the form for creating a new Shein item.
     *
     * @return \Illuminate\View\View
     */
    public function createShein(Request $request)
    {
        ResponseService::noAnyPermissionThenRedirect(['shein-products-create']);
        $categoryPool = $this->getCategoryPool();
        $categoryIds = $this->collectSectionCategoryIds($categoryPool, 4);

        $categories = collect($this->buildCategoryOptionTree($categoryPool, 4));
        $rootCategory = $categoryPool->firstWhere('id', 4);

        if ($rootCategory) {
            $categories->prepend([
                'id' => $rootCategory->id,
                'label' => $rootCategory->name,
                'name' => $rootCategory->name,
                'icon' => $rootCategory->image,
            ]);
        }

        $categoryIcons = $categoryPool
            ->filter(static fn ($category) => in_array($category->id, $categoryIds, true))
            ->mapWithKeys(static fn ($category) => [
                $category->id => $category->image,
            ])
            ->filter();

        $customFields = CustomField::whereHas('custom_field_category', function ($q) use ($categoryIds) {
            $q->whereIn('category_id', $categoryIds);
        })->where('status', 1)->orderBy('sequence')->get();

        return view('items.create_shein', [
            'categories' => $categories,
            'customFields' => $customFields,
            'categoryIcons' => $categoryIcons,
            'selectedCategoryId' => (int) $request->get('category_id', 4),
        ]);

    }

    /**
     * Store a newly created Shein item in storage.
     *
     * @param  \Illuminate\Http\Request  $request
     * @return \Illuminate\Http\Response
     */
    public function storeShein(Request $request)
    {
        try {
            ResponseService::noPermissionThenSendJson('shein-products-create');
            
            $categoryPool = $this->getCategoryPool();
            $allowedCategoryIds = $this->collectSectionCategoryIds($categoryPool, 4);

            $validationRules = [
                'name' => 'required|string|max:255',
                'description' => 'required|string',
                'price' => 'required|numeric',
                'currency' => 'required|string|max:10',
                'category_id' => 'required|exists:categories,id',
                'image' => 'required|image|mimes:jpeg,png,jpg,gif|max:2048',
                'gallery_images.*' => 'nullable|image|mimes:jpeg,png,jpg,gif|max:2048',
            ];


            $this->handleItemCreation($request, [
                'allowed_category_ids' => $allowedCategoryIds,
                'default_category_id' => 4,
                'section_root_id' => 4,
                'section' => DepartmentReportService::DEPARTMENT_SHEIN,
                'validation_rules' => array_merge($validationRules, [
                    'product_link' => ['required', 'url', 'max:2048'],
                    'review_link' => ['nullable', 'url', 'max:2048'],


                ]),
                'additional_attributes' => [
                    'product_link' => $request->input('product_link'),
                    'review_link' => $request->input('review_link'),


                ],


            ]);

            

            return redirect()
                ->route('item.shein.products')
                ->with('success', 'shein created successfully');

        } catch (ValidationException $exception) {
            return redirect()->back()->withErrors($exception->errors())->withInput();


        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'ItemController -> storeShein');

            return redirect()->back()->withErrors([
                'general' => $th->getMessage(),
            ])->withInput();



        }
    
    }


    public function storeComputer(Request $request)
    {
        try {
            ResponseService::noPermissionThenSendJson('computer-ads-create');

            

            $interfaceType = InterfaceSectionService::normalizeSectionType($request->input('interface_type', 'computer'));
            $sectionRoots = [
                'computer' => 5,
            ];
            $categoryPool = $this->getCategoryPool();
            $sectionRootId = $sectionRoots[$interfaceType] ?? $sectionRoots['computer'];
            $allowedCategoryIds = $this->collectSectionCategoryIds($categoryPool, $sectionRootId);



            $this->handleItemCreation($request, [
                'allowed_category_ids' => $allowedCategoryIds,
                'default_category_id' => $sectionRootId,
                'section_root_id' => $sectionRootId,
                'interface_type' => $interfaceType,
                'section' => DepartmentReportService::DEPARTMENT_COMPUTER,


            ]);


            return redirect()
                ->route('item.computer.products')
                ->with('success', 'Computer item created successfully');

        } catch (ValidationException $exception) {
            return redirect()->back()->withErrors($exception->errors())->withInput();



        } catch (Throwable $th) {




            ResponseService::logErrorResponse($th, 'ItemController -> storeComputer');

            return redirect()->back()->withErrors([
                'general' => $th->getMessage(),
            ])->withInput();
        }
    }

    /**
     * Show the form for editing the specified Shein item.
     *
     * @param  int  $id
     * @return \Illuminate\View\View
     */
    public function editShein($id)
    {
        ResponseService::noAnyPermissionThenRedirect(['shein-products-update']);
        
        $item = Item::with('gallery_images', 'item_custom_field_values.custom_field')->findOrFail($id);


        $categoryPool = $this->getCategoryPool();
        $categories = collect($this->buildCategoryOptionTree($categoryPool, 4));
        $categoryIds = $this->collectSectionCategoryIds($categoryPool, 4);

        $customFields = CustomField::whereHas('custom_field_category', function ($q) use ($categoryIds) {
            $q->whereIn('category_id', $categoryIds);
        })->where('status', 1)->orderBy('sequence')->get();
            
        return view('items.edit_shein', compact('item', 'categories', 'customFields'));
    }

    /**
     * Update the specified Shein item in storage.
     *
     * @param  \Illuminate\Http\Request  $request
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function updateShein(Request $request, $id)
    {
        try {
            ResponseService::noAnyPermissionThenSendJson(['shein-products-update']);
            
            $authorization = Gate::inspect('section.update', DepartmentReportService::DEPARTMENT_SHEIN);

            if ($authorization->denied()) {
                $message = $authorization->message() ?? SectionDelegatePolicy::FORBIDDEN_MESSAGE;

                ResponseService::errorResponse($message, null, 403);
            }

            $request->validate([
                'name' => 'required|string|max:255',
                'description' => 'required|string',
                'price' => 'required|numeric',
                'currency' => 'required|string|max:10',
                'category_id' => 'required|exists:categories,id',
                'status' => 'required|string|in:review,approved,rejected',
                'rejected_reason' => 'nullable|string',
                'image' => 'nullable|image|mimes:jpeg,png,jpg,gif|max:2048',
                'gallery_images.*' => 'nullable|image|mimes:jpeg,png,jpg,gif|max:2048',
                'product_link' => ['required', 'url', 'max:2048'],
                'review_link' => ['nullable', 'url', 'max:2048'],


            ]);

            $item = Item::findOrFail($id);
            
            // Update image if provided
            if ($request->hasFile('image')) {
                try {
                    $variants = ImageVariantService::storeWithVariants($request->file('image'), 'items');
                } catch (Throwable $exception) {
                    ResponseService::validationErrors([
                        'image' => [__('Unable to process the uploaded image. Please try again with a different file.')],
                    ]);
                }
                ImageVariantService::deleteStoredVariants([
                    $item->getRawOriginal('image'),
                    $item->getRawOriginal('thumbnail_url'),
                    $item->getRawOriginal('detail_image_url'),
                ]);

                $item->image = $variants['original'];
                $item->thumbnail_url = $variants['thumbnail'];
                $item->detail_image_url = $variants['detail'];
            }

            // Update item details
            $item->name = $request->name;
            $item->description = $request->description;
            $item->price = $request->price;
            $item->currency = $request->currency;
            $item->category_id = $request->category_id;
            $item->country = $request->country ?? '';
            $item->state = $request->state ?? '';
            $item->city = $request->city ?? '';
            $item->address = $request->address ?? '';
            $item->contact = $request->contact ?? '';            
            $item->product_link = $request->input('product_link');
            $item->review_link = $request->input('review_link');

            // Update status and rejection reason
            $item->status = $request->status;
            $item->rejected_reason = ($request->status == 'rejected') ? $request->rejected_reason : '';
            
            $item->save();

            // Upload gallery images if any
            if ($request->hasFile('gallery_images')) {
                foreach ($request->file('gallery_images') as $image) {
                    try {
                        $galleryVariants = ImageVariantService::storeWithVariants($image, 'items/gallery');
                    } catch (Throwable $exception) {
                        ResponseService::validationErrors([
                            'gallery_images' => [__('Unable to process one of the gallery images. Please verify the files and retry.')],
                        ]);
                    }
                    
                    $item->gallery_images()->create([
                        'image' => $galleryVariants['original'],
                        'thumbnail_url' => $galleryVariants['thumbnail'],
                        'detail_image_url' => $galleryVariants['detail'],
                    ]);
                }
            }

            // Delete gallery images if requested
            if ($request->has('delete_gallery_images')) {
                $deleteIds = explode(',', $request->delete_gallery_images);
                foreach ($deleteIds as $deleteId) {
                    $galleryImage = $item->gallery_images()->find($deleteId);
                    if ($galleryImage) {
                        ImageVariantService::deleteStoredVariants([
                            $galleryImage->getRawOriginal('image'),
                            $galleryImage->getRawOriginal('thumbnail_url'),
                            $galleryImage->getRawOriginal('detail_image_url'),
                        ]);
                        $galleryImage->delete();
                    }
                }
            }
            
            // Handle custom field values
            if ($request->custom_fields) {
                $itemCustomFieldValues = [];
                foreach ($request->custom_fields as $key => $custom_field) {
                    $itemCustomFieldValues[] = [
                        'item_id' => $item->id,
                        'custom_field_id' => $key,
                        'value' => json_encode($custom_field),
                        'updated_at' => now()
                    ];
                }

                if (count($itemCustomFieldValues) > 0) {
                    ItemCustomFieldValue::upsert($itemCustomFieldValues, ['item_id', 'custom_field_id'], ['value', 'updated_at']);
                }
            }

            // Handle custom field files
            if ($request->hasFile('custom_field_files')) {
                $itemCustomFieldValues = [];
                foreach ($request->file('custom_field_files') as $key => $file) {
                    $value = ItemCustomFieldValue::where(['item_id' => $item->id, 'custom_field_id' => $key])->first();
                    if (!empty($value)) {
                        $filePath = FileService::replace($file, 'custom_fields_files', $value->getRawOriginal('value'));
                    } else {
                        $filePath = FileService::upload($file, 'custom_fields_files');
                    }
                    $itemCustomFieldValues[] = [
                        'item_id' => $item->id,
                        'custom_field_id' => $key,
                        'value' => $filePath,
                        'updated_at' => now()
                    ];
                }

                if (count($itemCustomFieldValues) > 0) {
                    ItemCustomFieldValue::upsert($itemCustomFieldValues, ['item_id', 'custom_field_id'], ['value', 'updated_at']);
                }
            }

            return redirect()->route('item.shein.products');
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'ItemController -> updateShein');
            return redirect()->back()->withErrors([
                'general' => $th->getMessage(),
            ])->withInput();
        }
    }

    public function request() {
        ResponseService::noAnyPermissionThenRedirect(['item-list', 'item-update', 'item-delete']);
        return view('items.requests');
    }




    public function details(Item $item)
    {
        try {
            $item = Item::with([
                'user',
                'category',
                'gallery_images',
                'custom_fields',
                'item_custom_field_values',
                'featured_items',
                'favourites',
                'item_offers.seller',
                'item_offers.buyer',
                'cartItems.user',
                'user_reports.user',
                'user_reports.report_reason',
                'sliders',
                'area',
                'review.seller',
                'review.buyer',
            ])->withTrashed()->findOrFail($item->getKey());

            $viewPermissions = $this->resolvePermissionsForItem($item, 'list', 'item-list');
            ResponseService::noAnyPermissionThenRedirect($viewPermissions);

            $customFieldValues = $item->item_custom_field_values->keyBy('custom_field_id');
            $customFields = collect($item->custom_fields)->map(function ($customField) use ($customFieldValues) {
                $valueModel = $customFieldValues->get($customField->id);
                $fileUrls = [];
                $displayValue = null;

                if ($customField->type === 'fileinput') {
                    $rawValue = $valueModel?->value;

                    if ($customField->type === 'color') {
                        $entries = ColorFieldParser::parse($rawValue);
                        $displayValue = implode(', ', ColorFieldParser::labels($entries));
                    } elseif (is_array($rawValue)) {
                        
                        $fileUrls = collect($rawValue)
                            ->filter()
                            ->map(static function ($value) {
                                if (! is_string($value) || empty($value)) {
                                    return null;
                                }

                                if (str_starts_with($value, 'http://') || str_starts_with($value, 'https://')) {
                                    return $value;
                                }

                                return url(Storage::url($value));
                            })
                            ->filter()
                            ->values()
                            ->all();
                    } elseif (! empty($rawValue)) {
                        $fileUrls = [
                            str_starts_with($rawValue, 'http://') || str_starts_with($rawValue, 'https://')
                                ? $rawValue
                                : url(Storage::url($rawValue)),
                        ];
                    }
                } else {
                    $rawValue = $valueModel?->value;

                    if (is_array($rawValue)) {
                        $displayValue = implode(', ', array_filter($rawValue, static fn ($value) => $value !== null && $value !== ''));
                    } else {
                        $displayValue = $rawValue;
                    }
                }

                return [
                    'id' => $customField->id,
                    'name' => $customField->name,
                    'type' => $customField->type,
                    'image' => $customField->image,
                    'description' => $customField->description,
                    'value_model' => $valueModel,
                    'display_value' => $displayValue,
                    'file_urls' => $fileUrls,
                    'color_entries' => $customField->type === 'color'
                        ? ColorFieldParser::parse($valueModel?->value)
                        : [],

                ];
            });

            $updatePermissions = $this->resolvePermissionsForItem($item, 'update', 'item-update');
            $deletePermissions = $this->resolvePermissionsForItem($item, 'delete', 'item-delete');

            $isSheinItem = $item->category_id == 4 || ($item->category && $item->category->parent_category_id == 4);


            $mapsLink = null;
            if (filled($item->latitude) && filled($item->longitude)) {
                $mapsLink = sprintf(
                    'https://www.google.com/maps?q=%s,%s',
                    rawurlencode((string) $item->latitude),
                    rawurlencode((string) $item->longitude)
                );
            }

            $statistics = [
                [
                    'label' => __('Views'),
                    'value' => number_format((int) ($item->clicks ?? 0)),
                    'icon' => 'fa-eye',
                ],
                [
                    'label' => __('Likes'),
                    'value' => number_format($item->favourites->count()),
                    'icon' => 'fa-heart',
                ],
                [
                    'label' => __('Offers'),
                    'value' => number_format($item->item_offers->count()),
                    'icon' => 'fa-handshake',
                ],
                [
                    'label' => __('In Carts'),
                    'value' => number_format($item->cartItems->count()),
                    'icon' => 'fa-shopping-cart',
                ],
                [
                    'label' => __('Reports'),
                    'value' => number_format($item->user_reports->count()),
                    'icon' => 'fa-flag',
                ],
                [
                    'label' => __('Featured Slots'),
                    'value' => number_format($item->featured_items->count()),
                    'icon' => 'fa-star',
                ],
            ];


            return view('items.show', [
                'item' => $item,
                'customFields' => $customFields,
                'canUpdate' => $this->userHasAnyPermission($updatePermissions),
                'canDelete' => $this->userHasAnyPermission($deletePermissions),
                'canFeature' => $this->userHasAnyPermission($updatePermissions),
                'statusOptions' => [
                    'review' => __('Under Review'),
                    'approved' => __('Approve'),
                    'rejected' => __('Reject'),
                    'sold out' => __('Sold Out'),
                ],
                'isSheinItem' => $isSheinItem,
                'viewPermissions' => $viewPermissions,
                'updatePermissions' => $updatePermissions,
                'deletePermissions' => $deletePermissions,
                'mapsLink' => $mapsLink,
                'statistics' => $statistics,

            ]);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'ItemController -> details');

            return redirect()->back()->withErrors([
                'general' => $th->getMessage(),
            ]);
        }
    }







    public function listData(Request $request) {
        return $this->show($request);
    }

    public function show(Request $request, $itemId = null) {
        
        try {

            
            
            $section = $request->input('section');
            $categoryRootId = $request->input('category_root');

            if ($categoryRootId !== null && ! is_numeric($categoryRootId)) {
                $categoryRootId = null;
            } elseif ($categoryRootId !== null) {
                $categoryRootId = (int) $categoryRootId;



                            }

            $permissions = array_merge(
                $this->resolveContextPermissions($section, $categoryRootId, 'list', 'item-list'),
                $this->resolveContextPermissions($section, $categoryRootId, 'update', 'item-update'),
                $this->resolveContextPermissions($section, $categoryRootId, 'delete', 'item-delete'),
            );

            $permissions = array_unique($permissions);



            ResponseService::noAnyPermissionThenSendJson($permissions);
            $offset = $request->input('offset', 0);
            $limit = $request->input('limit', 10);
            $sort = $request->input('sort', 'id');
            $order = $request->input('order', 'ASC');
            $sql = Item::with([
                'custom_fields',
                'category:id,name',
                'user' => function ($q) {
                    $q->withTrashed()->select('id', 'name');
                },
                'user.store' => function ($q) {
                    $q->withTrashed()->select('id', 'user_id', 'name');
                },
                'gallery_images',
                'featured_items'
            ])->withTrashed();



            
            if (! $categoryRootId && ! empty($section)) {
                $sectionRoots = [
                    'shein' => 4,
                    'computer' => 5,
                ];

                $categoryRootId = $sectionRoots[$section] ?? null;


            }
            



            $categoryIds = [];
            $sectionCategoryIds = [];

            if ($categoryRootId) {
                $categoryPool = $this->getCategoryPool();
                $sectionCategoryIds = $this->collectSectionCategoryIds($categoryPool, $categoryRootId);
                $categoryIds = $sectionCategoryIds;
            }

            $selectedCategoryId = null;
            if (! empty($request->category_id)) {
                $selectedCategoryId = (int) $request->category_id;
            } elseif (! empty($request->subcategory_id)) {
                $selectedCategoryId = (int) $request->subcategory_id;
            }

            if ($selectedCategoryId !== null) {
                if ($categoryRootId && $selectedCategoryId === $categoryRootId && ! empty($sectionCategoryIds)) {
                    $categoryIds = $sectionCategoryIds;
                } else {
                    $categoryIds = [$selectedCategoryId];
                }
            }

            if (! empty($categoryIds)) {
                $sql = $sql->whereIn('category_id', $categoryIds);
            }





            if (!empty($request->search)) {
                $sql = $sql->search($request->search);
            }

            if (!empty($request->filter)) {
                $sql = $sql->filter(json_decode($request->filter, false, 512, JSON_THROW_ON_ERROR));
            }
            
            // Filter by status
            $status = $request->input('status');

            if (is_string($status)) {
                $status = trim($status);

                $normalizedStatus = strtolower($status);

                if ($normalizedStatus === '' || $normalizedStatus === 'undefined' || $normalizedStatus === 'null' || $normalizedStatus === 'all') {
                    $status = null;
                }
            }

            if ($status !== null && $status !== '') {
                $sql = $sql->where('status', $status);

                
            }

            $total = $sql->count();
            $sql = $sql->sort($sort, $order)->skip($offset)->take($limit);
            $result = $sql->get();

            $bulkData = array();
            $bulkData['total'] = $total;
            $rows = array();

            $itemCustomFieldValues = ItemCustomFieldValue::whereIn('item_id', $result->pluck('id'))->get();
            foreach ($result as $row) {
                /* Merged ItemCustomFieldValue's data to main data */
                $itemCustomFieldValue = $itemCustomFieldValues->filter(function ($data) use ($row) {
                    return $data->item_id == $row->id;
                });

                $row->custom_fields = collect($row->custom_fields)->map(function ($customField) use ($itemCustomFieldValue) {
                    $customField['value'] = $itemCustomFieldValue->first(function ($data) use ($customField) {
                        return $data->custom_field_id == $customField->id;
                    });

                    if ($customField->type == "fileinput" && !empty($customField['value']->value)) {
                        if (!is_array($customField->value)) {
                            $customField['value'] = !empty($customField->value) ? [url(Storage::url($customField->value))] : [];
                        } else {
                            $customField['value'] = null;
                        }
//                        $customField['value']->value = url(Storage::url($customField['value']->value));
                    }
                    return $customField;
                });
                $tempRow = $row->toArray();
                $operate = '';
                

                // اسم المعلن: متجر أو اسم المستخدم أو "-"
                $advertiserName = trim($row->user->store->name ?? '') ?: trim($row->user->name ?? '') ?: '-';

                $tempRow['user'] = ['name' => $advertiserName];
                $tempRow['user_name'] = $advertiserName;


                $permissionPrefix = $this->resolvePermissionPrefixFromCategoryId($row->category_id);
                $viewPermissions = $this->buildPermissionList($permissionPrefix, 'list', 'item-list');
                $updatePermissions = $this->buildPermissionList($permissionPrefix, 'update', 'item-update');
                $deletePermissions = $this->buildPermissionList($permissionPrefix, 'delete', 'item-delete');

                // Check if this is a Shein item (category_id = 4 or parent_category_id = 4)
                $isSheinItem = ($row->category_id == 4 || ($row->category && $row->category->parent_category_id == 4));
                
                if ($this->userHasAnyPermission($viewPermissions)) {
                    // View details button


                    $operate .= BootstrapTableService::button(
                        'fa fa-eye',
                        route('item.details', $row->id),
                        ['btn-outline-primary'],
                        [
                            'title' => __('View'),
                        ],
                        ''
                    );
                }

                if ($row->status !== 'sold out' && $this->userHasAnyPermission($updatePermissions)) {
                    // Add status edit button - only show if not on shein page
                    if ($request->route()->getName() != 'item.shein.products') {
                        $operate .= BootstrapTableService::editButton(
                            route('item.approval', $row->id),
                            true,
                        '#editStatusModal',
                        'edit-status',
                        $row->id,
                        'fa fa-edit',
                        null,
                        ''
                    );
                    
                    
                    }
                    
                    // Add edit button for Shein items with more prominence
                    if ($isSheinItem || $request->route()->getName() == 'item.shein.products') {
                        $operate .= BootstrapTableService::button(
                            'fa fa-edit',
                            route('item.shein.products.edit', $row->id),
                            ['edit-item', 'btn-success', 'btn-sm', 'me-1'],
                            ['title' => __("Edit All Data")],
                            ''
                        );


                    }





                }
                
                if ($this->userHasAnyPermission($deletePermissions)) {
                    $operate .= BootstrapTableService::deleteButton(
                        route('item.destroy', $row->id),
                        null,
                        null,
                        null,
                        null,
                        ''
                    );
                
                }
                
                $tempRow['active_status'] = empty($row->deleted_at);//IF deleted_at is empty then status is true else false
                $tempRow['operate'] = $operate;

                $rows[] = $tempRow;
            }
            $bulkData['rows'] = $rows;
            return response()->json($bulkData);

        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "ItemController --> show");
            return ResponseService::errorResponse();
        }
    }

    public function updateItemApproval(Request $request, $id) {
        try {
            $item = Item::with(['user', 'category:id,parent_category_id'])->withTrashed()->findOrFail($id);
            ResponseService::noAnyPermissionThenSendJson($this->resolvePermissionsForItem($item, 'update', 'item-update'));


            $item->update([
                ...$request->all(),
                'rejected_reason' => ($request->status == "rejected") ? $request->rejected_reason : ''
            ]);
            $user_token = UserFcmToken::where('user_id', $item->user->id)->pluck('fcm_token')->toArray();
            if (!empty($user_token)) {
                $notificationResponse = NotificationService::sendFcmNotification(
                    $user_token,
                    'About ' . $item->name,
                    "Your Item is " . ucfirst($request->status),
                    "item-update",
                    ['id' => $request->id]
                );

                if (is_array($notificationResponse) && ($notificationResponse['error'] ?? false)) {
                    Log::error('ItemController: Failed to send status notification', $notificationResponse);

                    ResponseService::warningResponse(
                        $notificationResponse['message'] ?? 'Failed to send item notification.',
                        $notificationResponse,
                        $notificationResponse['code'] ?? null
                    );
                }

            }
            ResponseService::successResponse('Item Status Updated Successfully');
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'ItemController ->updateItemApproval');
            ResponseService::errorResponse(
                $th->getMessage(),
                ['error' => true, 'code' => $th->getCode()],
                $th->getCode() ?: null,
                $th
            );
        }
    }

    public function destroy($id) {

        try {
            $item = Item::with(['gallery_images', 'category:id,parent_category_id'])->withTrashed()->findOrFail($id);
            ResponseService::noAnyPermissionThenSendJson($this->resolvePermissionsForItem($item, 'delete', 'item-delete'));


            foreach ($item->gallery_images as $gallery_image) {
                ImageVariantService::deleteStoredVariants([
                    $gallery_image->getRawOriginal('image'),
                    $gallery_image->getRawOriginal('thumbnail_url'),
                    $gallery_image->getRawOriginal('detail_image_url'),
                ]);
            
            }
            ImageVariantService::deleteStoredVariants([
                $item->getRawOriginal('image'),
                $item->getRawOriginal('thumbnail_url'),
                $item->getRawOriginal('detail_image_url'),
            ]);


            $item->forceDelete();

            ResponseService::successResponse('Item deleted successfully');
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th);
            ResponseService::errorResponse('Something went wrong');
        }
    }



    public function feature(Item $item)
    {
        try {
            ResponseService::noAnyPermissionThenSendJson($this->resolvePermissionsForItem($item, 'update', 'item-update'));

            $existingFeature = FeaturedItems::where('item_id', $item->id)
                ->onlyActive()
                ->first();

            if ($existingFeature) {
                ResponseService::errorResponse('Item is already featured');
            }

            FeaturedItems::updateOrCreate(
                ['item_id' => $item->id],
                [
                    'package_id'                => null,
                    'user_purchased_package_id' => null,
                    'start_date'                => Carbon::now()->toDateString(),
                    'end_date'                  => null,
                ]
            );

            ResponseService::successResponse('Item featured successfully');
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'ItemController -> feature');
            ResponseService::errorResponse($th->getMessage(), null, $th->getCode() ?: null, $th);
        }
    }



    /**
     * البحث عن العناصر بناءً على الاسم
     * 
     * @param Request $request
     * @return \Illuminate\Http\JsonResponse
     */
    public function search(Request $request)
    {
        try {
            $query = $request->input('q', '');
            $items = Item::where('name', 'like', '%' . $query . '%')
                ->where('status', 'approved')
                ->select('id', 'name', 'price')
                ->limit(10)
                ->get();

            return response()->json($items);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'ItemController -> search');
            return response()->json([]);
        }
    }


    public function computer()
    {
        ResponseService::noAnyPermissionThenRedirect([
            'computer-ads-list', 'computer-ads-update', 'computer-ads-delete', 'computer-ads-create',
            'computer-orders-list', 'computer-requests-list', 'staff-list', 'reports-orders', 'chat-monitor-list'
        ]);

        $advertiser = $this->departmentAdvertiserService->getAdvertiser(DepartmentReportService::DEPARTMENT_COMPUTER);

        return view('items.computer.index', compact('advertiser'));
    
        }

    public function computerProducts()
    {
        
        
        ResponseService::noAnyPermissionThenRedirect(['computer-ads-list', 'computer-ads-update', 'computer-ads-delete']);
     
        $categoryPool = $this->getCategoryPool();
        $categoryIds = $this->collectSectionCategoryIds($categoryPool, 5, true);

        $categories = $categoryPool
            ->filter(static fn ($category) => in_array($category->id, $categoryIds, true))
            ->sortBy(static function ($category) {
                $sequence = $category->sequence ?? 999999;

                return sprintf('%06d-%s', $sequence, $category->name);
            })
            ->values();

        return view('items.computer', compact('categories'));
    }

    public function computerCreate(Request $request)

    {
        ResponseService::noAnyPermissionThenRedirect(['computer-ads-create']);

        $categoryPool = $this->getCategoryPool();
        $categoryIds = $this->collectSectionCategoryIds($categoryPool, 5);

        $categories = collect($this->buildCategoryOptionTree($categoryPool, 5));
        $rootCategory = $categoryPool->firstWhere('id', 5);

        if ($rootCategory) {
            $categories->prepend([
                'id' => $rootCategory->id,
                'label' => $rootCategory->name,
                'name' => $rootCategory->name,


            ]);
        }



        $customFields = CustomField::whereHas('custom_field_category', function ($q) use ($categoryIds) {
            $q->whereIn('category_id', $categoryIds);
        })->where('status', 1)->get();



                return view('items.computer.create', [
            'categories' => $categories,
            'customFields' => $customFields,
            'selectedCategoryId' => (int) $request->get('category_id', 5),
        ]);
    }

    public function computerPublish()

    {
        ResponseService::noAnyPermissionThenRedirect(['computer-ads-create']);

        return redirect()->route('item.computer.create', [
            'category_id' => 5,
            'interfaceType' => 'computer',
        ]);

    }



    private function handleItemCreation(Request $request, array $context = []): Item
    {
        $validationRules = $context['validation_rules'] ?? [
            'name' => 'required|string|max:255',
            'description' => 'required|string',
            'price' => 'required|numeric',
            'currency' => 'required|string|max:10',
            'category_id' => 'required|exists:categories,id',
            'image' => 'required|image|mimes:jpeg,png,jpg,gif|max:2048',
            'gallery_images.*' => 'nullable|image|mimes:jpeg,png,jpg,gif|max:2048',
        ];

        $request->validate($validationRules);

        $categoryId = (int) ($request->input('category_id') ?? 0);

        if (! $categoryId && isset($context['default_category_id'])) {
            $categoryId = (int) $context['default_category_id'];
        }

        if (! empty($context['allowed_category_ids']) && ! in_array($categoryId, $context['allowed_category_ids'], true)) {
            $categoryId = (int) ($context['default_category_id'] ?? $categoryId);
        }


        $section = $context['section'] ?? null;
        if ($section !== null) {
            $authorization = Gate::inspect('section.publish', $section);

            if ($authorization->denied()) {
                $message = $authorization->message() ?? SectionDelegatePolicy::FORBIDDEN_MESSAGE;

                ResponseService::errorResponse($message, null, 403);
            }
        }


        try {
            $variants = ImageVariantService::storeWithVariants($request->file('image'), 'items');
        } catch (Throwable $exception) {
            ResponseService::validationErrors([
                'image' => [__('Unable to process the uploaded image. Please try again with a different file.')],
            ]);
        }



        $status = $context['status'] ?? 'review';

        if ($this->shouldAutoApproveSection($section)) {
            $status = 'approved';
        }



        $itemData = [
            'name' => $request->name,
            'description' => $request->description,
            'price' => $request->price,
            'currency' => $request->currency,
            'category_id' => $categoryId,
            'user_id' => Auth::id(),
            'image' => $variants['original'],
            'thumbnail_url' => $variants['thumbnail'],
            'detail_image_url' => $variants['detail'],
            'country' => $request->country ?? '',
            'state' => $request->state ?? '',
            'city' => $request->city ?? '',
            'address' => $request->address ?? '',
            'contact' => $request->contact ?? '',
            'status' => $status,

        ];

        if (! empty($context['interface_type'])) {
            $itemData['interface_type'] = $context['interface_type'];
        }



        if (! empty($context['additional_attributes']) && is_array($context['additional_attributes'])) {
            $itemData = array_merge($itemData, $context['additional_attributes']);
        }

        $item = Item::create($itemData);

        $this->attachGalleryImages($item, $request);
        $this->storeCustomFieldValues($item, $request);

        return $item;
    }

    private function attachGalleryImages(Item $item, Request $request): void
    {
        if (! $request->hasFile('gallery_images')) {
            return;
        }

        foreach ($request->file('gallery_images') as $image) {
            if (empty($image)) {
                continue;
            }

            try {
                $galleryVariants = ImageVariantService::storeWithVariants($image, 'items/gallery');
            } catch (Throwable $exception) {
                ResponseService::validationErrors([
                    'gallery_images' => [__('Unable to process one of the gallery images. Please verify the files and retry.')],
                ]);
            }
            
            $item->gallery_images()->create([
                'image' => $galleryVariants['original'],
                'thumbnail_url' => $galleryVariants['thumbnail'],
                'detail_image_url' => $galleryVariants['detail'],
            ]);
        }
    }

    private function storeCustomFieldValues(Item $item, Request $request): void
    {
        if ($request->custom_fields) {
            $itemCustomFieldValues = [];
            foreach ($request->custom_fields as $key => $custom_field) {
                $itemCustomFieldValues[] = [
                    'item_id' => $item->id,
                    'custom_field_id' => $key,
                    'value' => json_encode($custom_field),
                    'created_at' => now(),
                    'updated_at' => now(),
                ];
            }

            if (! empty($itemCustomFieldValues)) {
                ItemCustomFieldValue::insert($itemCustomFieldValues);
            }
        }

        if ($request->hasFile('custom_field_files')) {
            $itemCustomFieldValues = [];
            foreach ($request->file('custom_field_files') as $key => $file) {
                $itemCustomFieldValues[] = [
                    'item_id' => $item->id,
                    'custom_field_id' => $key,
                    'value' => ! empty($file) ? FileService::upload($file, 'custom_fields_files') : '',
                    'created_at' => now(),
                    'updated_at' => now(),
                ];
            }

            if (! empty($itemCustomFieldValues)) {
                ItemCustomFieldValue::insert($itemCustomFieldValues);
            }
        }
    }


    private function shouldAutoApproveSection(?string $section): bool
    {
        if ($section === null) {
            return false;
        }

        return in_array($section, [
            DepartmentReportService::DEPARTMENT_SHEIN,
            DepartmentReportService::DEPARTMENT_COMPUTER,
        ], true);
    }


    private function getCategoryPool(): Collection
    {
        return Category::select('id', 'name', 'parent_category_id', 'sequence', 'image')->get();

    }

    private function collectSectionCategoryIds(Collection $categories, int $rootId, bool $includeRoot = true): array
    {
        $ids = $includeRoot ? [$rootId] : [];
        $queue = [$rootId];

        while (! empty($queue)) {
            $current = array_shift($queue);
            $children = $categories->where('parent_category_id', $current);

            foreach ($children as $child) {
                if (! in_array($child->id, $ids, true)) {
                    $ids[] = $child->id;
                    $queue[] = $child->id;
                }
            }
        }

        return $ids;
    }

    private function buildCategoryOptionTree(Collection $categories, int $parentId, string $prefix = ''): array
    {
        $options = [];

        $children = $categories
            ->where('parent_category_id', $parentId)
            ->sortBy(static function ($category) {
                $sequence = $category->sequence ?? 999999;

                return sprintf('%06d-%s', $sequence, $category->name);
            });

        foreach ($children as $child) {
            $options[] = [
                'id' => $child->id,
                'label' => $prefix . $child->name,
                'name' => $child->name,
                'icon' => $child->image,

            ];

            $options = array_merge(
                $options,
                $this->buildCategoryOptionTree($categories, $child->id, $prefix . '— ')
            );
        }

        return $options;
    }



        private function resolveContextPermissions(?string $section, ?int $categoryRootId, string $action, string $fallbackPermission): array
    {
        $prefix = $this->resolvePermissionPrefixFromSection($section, $categoryRootId);

        return $this->buildPermissionList($prefix, $action, $fallbackPermission);
    }

    private function resolvePermissionPrefixFromSection(?string $section, ?int $categoryRootId): ?string
    {
        $sectionPrefixes = [
            'shein' => 'shein-products',
            'computer' => 'computer-ads',
        ];

        $categoryPrefixes = [
            4 => 'shein-products',
            5 => 'computer-ads',
        ];

        if ($section !== null && isset($sectionPrefixes[$section])) {
            return $sectionPrefixes[$section];
        }

        if ($categoryRootId !== null && isset($categoryPrefixes[$categoryRootId])) {
            return $categoryPrefixes[$categoryRootId];
        }

        return null;
    }

    private function buildPermissionList(?string $prefix, string $action, string $fallbackPermission): array
    {
        $permissions = [];

        if ($prefix !== null) {
            $permissions[] = sprintf('%s-%s', $prefix, $action);
        }

        if (! in_array($fallbackPermission, $permissions, true)) {
            $permissions[] = $fallbackPermission;
        }

        return $permissions;
    }

    private function resolvePermissionsForItem(Item $item, string $action, string $fallbackPermission): array
    {
        $prefix = $this->resolvePermissionPrefixFromCategoryId($item->category_id);

        return $this->buildPermissionList($prefix, $action, $fallbackPermission);
    }

    private function resolvePermissionPrefixFromCategoryId(?int $categoryId): ?string
    {
        if ($categoryId === null) {
            return null;
        }

        $categoryPrefixes = [
            4 => 'shein-products',
            5 => 'computer-ads',
        ];

        $checkedIds = [];
        $currentId = $categoryId;

        while ($currentId !== null) {
            if (isset($categoryPrefixes[$currentId])) {
                return $categoryPrefixes[$currentId];
            }

            if (in_array($currentId, $checkedIds, true)) {
                break;
            }

            $checkedIds[] = $currentId;

            $category = Category::select('id', 'parent_category_id')->find($currentId);

            if (! $category) {
                break;
            }

            $currentId = $category->parent_category_id;
        }

        return null;
    }

    private function userHasAnyPermission(array $permissions): bool
    {
        return Auth::user()->canany($permissions);
    }



}
