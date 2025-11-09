<?php

namespace App\Http\Controllers;

use App\Models\Category;
use App\Models\CategoryTranslation;
use App\Models\CustomField;
use App\Models\CustomFieldCategory;
use App\Services\BootstrapTableService;
use App\Services\CachingService;
use App\Services\FileService;
use App\Services\CategoryCloneService;
use App\Services\HelperService;
use App\Services\ResponseService;
use DB;
use Illuminate\Database\QueryException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Collection;

use Throwable;
use function compact;
use function view;

class CategoryController extends Controller {
    private string $uploadFolder;
    private CategoryCloneService $categoryCloneService;

    public function __construct(CategoryCloneService $categoryCloneService) {
        $this->uploadFolder = "category";
        $this->categoryCloneService = $categoryCloneService;
    }

    public function index() {
        ResponseService::noAnyPermissionThenRedirect(['category-list', 'category-create', 'category-update', 'category-delete']);
        return view('category.index');
    }

    public function create(Request $request) {
        $languages = CachingService::getLanguages()->where('code', '!=', 'en')->values();
        ResponseService::noPermissionThenRedirect('category-create');
        $categories = Category::with('subcategories')->get();
        return view('category.create', compact('categories', 'languages'));
    }

    public function store(Request $request) {
        ResponseService::noPermissionThenSendJson('category-create');
        $request->validate([
            'name'               => 'required',
            'image'              => 'required|mimes:jpg,jpeg,png|max:4096',
            'parent_category_id' => 'nullable|integer',
            'description'        => 'nullable',
            'slug'               => 'required',
            'status'             => 'required|boolean',
            'translations'       => 'nullable|array',
            'translations.*'     => 'nullable|string',
        ]);

        try {
            $data = $request->all();
            $data['slug'] = HelperService::generateUniqueSlug(new Category(), $request->slug);

            if ($request->hasFile('image')) {
                $data['image'] = FileService::compressAndUpload($request->file('image'), $this->uploadFolder);
            }

            $category = Category::create($data);

            if (!empty($request->translations)) {
                foreach ($request->translations as $key => $value) {
                    if (!empty($value)) {
                        $category->translations()->create([
                            'name'        => $value,
                            'language_id' => $key,
                        ]);
                    }
                }
            }

            ResponseService::successRedirectResponse("Category Added Successfully");
        } catch (Throwable $th) {
            ResponseService::logErrorRedirect($th);
            ResponseService::errorRedirectResponse();
        }
    }


    public function show(Request $request, $id) {
        ResponseService::noPermissionThenSendJson('category-list');
        $offset = $request->input('offset', 0);
        $limit = $request->input('limit', 10);
        $sort = $request->input('sort', 'sequence');
        $order = $request->input('order', 'ASC');
        $sql = Category::withCount('subcategories')->orderBy($sort, $order)->withCount('custom_fields');
        if ($id == "0") {
            $sql->whereNull('parent_category_id');
        } else {
            $sql->where('parent_category_id', $id);
        }
        if (!empty($request->search)) {
            $sql = $sql->search($request->search);
        }
        $total = $sql->count();
        $sql->skip($offset)->take($limit);
        $result = $sql->get();
        $bulkData = array();
        $bulkData['total'] = $total;
        $rows = array();
        $no = 1;

        foreach ($result as $key => $row) {
            $operate = '';
            if (Auth::user()->can('category-update')) {
                $operate .= BootstrapTableService::editButton(route('category.edit', $row->id));
            }

            if (Auth::user()->can('category-edit')) {
                $operate .= BootstrapTableService::deleteButton(route('category.destroy', $row->id));
            }


            if (Auth::user()->can('category-create')) {
                $operate .= BootstrapTableService::button(
                    'fas fa-clone',
                    '#',
                    ['btn-outline-primary', 'js-open-clone-category'],
                    [
                        'title' => __('نسخ الفئة'),
                        'data-category-id' => $row->id,
                        'data-category-name' => $row->name,
                        'data-options-url' => route('category.clone-targets', $row->id),
                        'data-action-url' => route('category.clone', $row->id),
                    ],
                    __('نسخ')
                );
            }

            if ($row->subcategories_count > 1) {
                $operate .= BootstrapTableService::button('fa fa-list-ol',route('sub.category.order.change', $row->id),['btn-secondary']);
            }
            $tempRow = $row->toArray();
            $tempRow['no'] = $no++;
            $tempRow['operate'] = $operate;
            $rows[] = $tempRow;
        }

        $bulkData['rows'] = $rows;
        return response()->json($bulkData);
    }


    public function cloneTargets(Category $category)
    {
        ResponseService::noPermissionThenSendJson('category-list');

        $excludedCategoryIds = HelperService::collectDescendantIds($category);
        $excludedCategoryIds[] = $category->id;

        $allCategories = Category::select('id', 'name', 'parent_category_id')->orderBy('name')->get();
        $availableCategories = $allCategories->reject(static function ($candidate) use ($excludedCategoryIds) {
            return in_array($candidate->id, $excludedCategoryIds, true);
        });

        $options = $this->buildCategorySelectOptions($availableCategories);

        return response()->json([
            'options' => $options,
        ]);
    }

    public function cloneCategory(Request $request, Category $category)
    {
        ResponseService::noPermissionThenRedirect('category-create');

        $validator = Validator::make($request->all(), [
            'source_category_id' => ['required', 'integer'],
            'target_parent_category_id' => ['required', 'integer', 'exists:categories,id'],
        ], [], [
            'target_parent_category_id' => __('الفئة الهدف'),
        ]);

        if ($validator->fails()) {
            return redirect()->back()->withErrors($validator)->withInput();
        }

        if ((int) $request->input('source_category_id') !== $category->id) {
            return redirect()->back()->withErrors([
                'source_category_id' => __('تم تغيير بيانات الفئة أثناء الإرسال. يرجى المحاولة مجدداً.'),
            ])->withInput();
        }

        $targetParentId = (int) $request->input('target_parent_category_id');

        $descendantIds = HelperService::collectDescendantIds($category);
        $descendantIds[] = $category->id;

        if (in_array($targetParentId, $descendantIds, true)) {
            return redirect()->back()->withErrors([
                'target_parent_category_id' => __('لا يمكن نسخ الفئة داخل نفس التسلسل الهرمي.'),
            ])->withInput();
        }

        try {
            $result = $this->categoryCloneService->cloneCategoryTree($category->id, $targetParentId);

            $message = __('تم نسخ الفئة بنجاح (:categories فئة جديدة، :fields حقل جديد، :attached ارتباطات).', [
                'categories' => $result['created_categories'],
                'fields' => $result['created_fields'],
                'attached' => $result['attached_fields'],
            ]);

            return redirect()->back()->with('success', $message);
        } catch (Throwable $th) {
            ResponseService::logErrorRedirect($th, 'CategoryController -> cloneCategory');

            return redirect()->back()->with('errors', __('تعذر نسخ الفئة. يرجى المحاولة مرة أخرى لاحقاً.'));
        }
    }


    public function edit($id) {
        ResponseService::noPermissionThenRedirect('category-update');
        $category_data = Category::findOrFail($id);
        // Fetch translations for the category
        $translations = $category_data->translations->pluck('name', 'language_id')->toArray();

        $parent_category_data = Category::find($category_data->parent_category_id);
        $parent_category = $parent_category_data->name ?? '';
        
        // Fetch all categories for parent selection
        $categories = Category::where('id', '!=', $id)->get();

        // Fetch all languages
        $languages = CachingService::getLanguages()->where('code', '!=', 'en')->values();

        return view('category.edit', compact('category_data', 'parent_category', 'translations', 'languages', 'categories'));
    }

    public function update(Request $request, $id) {
        ResponseService::noPermissionThenSendJson('category-update');
        try {
            $request->validate([
                'name'            => 'nullable',
                'image'           => 'nullable|mimes:jpg,jpeg,png|max:4096',
                'parent_category_id' => 'nullable',
                'description'     => 'nullable',
                'slug'            => 'nullable',
                'status'          => 'required|boolean',
                'translations'    => 'nullable|array',
                'translations.*'  => 'nullable|string',
            ]);

    
        $category = Category::with('subcategories')->findOrFail($id);

            $data = $request->all();
            if ($request->hasFile('image')) {
                $data['image'] = FileService::compressAndReplace($request->file('image'), $this->uploadFolder, $category->getRawOriginal('image'));
            }
            $data['slug'] = HelperService::generateUniqueSlug(new Category(), $request->slug, $category->id);
            
            // Handle empty parent_category_id as null (main category)
            if ($request->has('parent_category_id') && $request->parent_category_id === '') {
                $data['parent_category_id'] = null;
            }
            
            $category->update($data);

            if (!empty($request->translations)) {
                $categoryTranslations = [];
                foreach ($request->translations as $key => $value) {
                    $categoryTranslations[] = [
                        'category_id' => $category->id,
                        'language_id' => $key,
                        'name'        => $value,
                    ];
                }

                if (count($categoryTranslations) > 0) {
                    CategoryTranslation::upsert($categoryTranslations, ['category_id', 'language_id'], ['name']);
                }
            }

            ResponseService::successRedirectResponse("Category Updated Successfully", route('category.index'));
        } catch (Throwable $th) {
            ResponseService::logErrorRedirect($th);
            ResponseService::errorRedirectResponse('Something Went Wrong');
        }
    }

    public function destroy($id) {
        ResponseService::noPermissionThenSendJson('category-delete');
        try {

            $category = Category::with('subcategories')->findOrFail($id);

            if ($category->delete()) {
                ResponseService::successResponse('Category delete successfully');
            }
        } catch (QueryException $th) {
            ResponseService::logErrorResponse($th, 'Failed to delete category', 'Cannot delete category. Remove associated subcategories and custom fields first.');
            ResponseService::errorResponse('Something Went Wrong');
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "CategoryController -> delete");
            ResponseService::errorResponse('Something Went Wrong');
        }
    }

    public function getSubCategories($id) {
        ResponseService::noPermissionThenRedirect('category-list');
        $subcategories = Category::where('parent_category_id', $id)
            ->withCount('custom_fields')
            ->withCount('subcategories')
            ->orderBy('sequence')
            ->get()
            ->map(function ($subcategory) {
                $operate = '';
                if (Auth::user()->can('category-update')) {
                    $operate .= BootstrapTableService::editButton(route('category.edit', $subcategory->id));
                }
                if (Auth::user()->can('category-delete')) {
                    $operate .= BootstrapTableService::deleteButton(route('category.destroy', $subcategory->id));
                }
                if ($subcategory->subcategories_count > 1) {
                    $operate .= BootstrapTableService::button('fa fa-list-ol',route('sub.category.order.change',$subcategory->id),['btn-secondary']);
                }
                $subcategory->operate = $operate;
                return $subcategory;
            });

        return response()->json($subcategories);
    }

    public function customFields($id) {
        ResponseService::noPermissionThenRedirect('custom-field-list');
        $category = Category::find($id);
        $p_id = $category->parent_category_id;
        $cat_id = $category->id;
        $category_name = $category->name;
        
        // Count custom fields for this category
        $customFieldsCount = CustomField::whereHas('categories', function ($query) use ($id) {
            $query->where('category_id', $id);
        })->count();


        
        $excludedCategoryIds = HelperService::collectDescendantIds($category);
        $excludedCategoryIds[] = $category->id;

        $allCategories = Category::select('id', 'name', 'parent_category_id')->orderBy('name')->get();
        $availableCategories = $allCategories->reject(static function ($candidate) use ($excludedCategoryIds) {
            return in_array($candidate->id, $excludedCategoryIds, true);
        });
        $cloneTargetOptions = $this->buildCategorySelectOptions($availableCategories);

        return view('category.custom-fields', compact('cat_id', 'category_name', 'p_id', 'customFieldsCount', 'cloneTargetOptions'));
    }

    private function buildCategorySelectOptions(Collection $categories, ?int $parentId = null, int $depth = 0): array
    {
        $options = [];

        $children = $categories
            ->filter(static function ($category) use ($parentId) {
                return $parentId === null ? $category->parent_category_id === null : (int)$category->parent_category_id === $parentId;
            })
            ->sortBy('name');

        foreach ($children as $child) {
            $options[] = [
                'id' => $child->id,
                'label' => str_repeat('— ', $depth) . $child->name,
            ];

            $options = array_merge($options, $this->buildCategorySelectOptions($categories, $child->id, $depth + 1));
        }

        return $options;
    
    
    }

    public function getCategoryCustomFields(Request $request, $id) {
        ResponseService::noPermissionThenSendJson('custom-field-list');
        $offset = $request->input('offset', 0);
        $limit = $request->input('limit', 10);
        $sort = $request->input('sort', 'id');
        $order = $request->input('order', 'ASC');

        $sql = CustomField::whereHas('categories', static function ($q) use ($id) {
            $q->where('category_id', $id);
        });
        
        // Default ordering by sequence if not specified
        if ($sort === 'id' && $order === 'ASC') {
            $sql->orderBy('sequence', 'ASC');
        } else {
            $sql->orderBy($sort, $order);
        }

        if (isset($request->search)) {
            $sql->search($request->search);
        }

        $sql->take($limit);
        $total = $sql->count();
        $res = $sql->skip($offset)->take($limit)->get();
        $bulkData = array();
        $rows = array();
        $tempRow['type'] = '';


        foreach ($res as $row) {
            $tempRow = $row->toArray();
//            $operate = BootstrapTableService::editButton(route('custom-fields.edit', $row->id));
            $operate = BootstrapTableService::deleteButton(route('category.custom-fields.destroy', [$id, $row->id]));
            $tempRow['operate'] = $operate;
            $rows[] = $tempRow;
        }

        $bulkData['rows'] = $rows;
        $bulkData['total'] = $total;
        return response()->json($bulkData);
    }

    public function destroyCategoryCustomField($categoryID, $customFieldID) {
        try {
            ResponseService::noPermissionThenRedirect('custom-field-delete');
            CustomFieldCategory::where(['category_id' => $categoryID, 'custom_field_id' => $customFieldID])->delete();
            ResponseService::successResponse("Custom Field Deleted Successfully");
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "CategoryController -> destroyCategoryCustomField");
            ResponseService::errorResponse('Something Went Wrong');
        }

    }

    public function categoriesReOrder(Request $request) {
        $categories = Category::whereNull('parent_category_id')->orderBy('sequence')->get();
        return view('category.categories-order', compact('categories'));
    }

    public function subCategoriesReOrder(Request $request ,$id) {
        $categories = Category::with('subcategories')->where('parent_category_id', $id)->orderBy('sequence')->get();
        return view('category.sub-categories-order', compact('categories'));
    }

    public function updateOrder(Request $request) {
        $request->validate([
           'order' => 'required|json'
        ]);
        try {

            $order = json_decode($request->input('order'), true);
            $data = [];
        foreach ($order as $index => $id) {
            $data[] = [
                'id' => $id,
                'sequence' => $index + 1,
            ];
        }
        Category::upsert($data, ['id'], ['sequence']);
        ResponseService::successResponse("Order Updated Successfully");
        } catch (Throwable $th) {
            ResponseService::logErrorRedirect($th);
            ResponseService::errorResponse('Something Went Wrong');
        }
    }
}
